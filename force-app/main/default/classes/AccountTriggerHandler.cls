public class AccountTriggerHandler extends TriggerHandler {
  // -------------------- Type Helpers --------------------

  private List<Account> getAccountList(List<SObject> records) {
    return (List<Account>) records;
  }

  private Map<Id, Account> getAccountMap(Map<Id, SObject> recordMap) {
    return (Map<Id, Account>) recordMap;
  }

  // -------------------- BEFORE INSERT --------------------

  protected override void beforeInsert(List<SObject> newRecords) {
    List<Account> newAccountList = getAccountList(newRecords);

    duplicateSicValidation(newAccountList, null, null);
  }

  // -------------------- AFTER INSERT --------------------

  protected override void afterInsert(
    List<SObject> newRecords,
    Map<Id, SObject> newRecordMap
  ) {
    List<Account> newAccountList = getAccountList(newRecords);
    Map<Id, Account> newAccountMap = getAccountMap(newRecordMap);

    for (Account accountRecord : newAccountList) {
      Account insertedAccount = newAccountMap.get(accountRecord.Id);

      // Example logic
      System.debug('Inserted Account Id: ' + insertedAccount.Id);
    }
  }

  // -------------------- BEFORE UPDATE --------------------

  protected override void beforeUpdate(
    List<SObject> newRecords,
    List<SObject> oldRecords,
    Map<Id, SObject> newRecordMap,
    Map<Id, SObject> oldRecordMap
  ) {
    List<Account> newAccountList = getAccountList(newRecords);
    List<Account> oldAccountList = getAccountList(oldRecords);
    Map<Id, Account> oldAccountMap = getAccountMap(oldRecordMap);
    Map<Id, Account> newAccountMap = getAccountMap(newRecordMap);

    duplicateSicValidation(newAccountList, oldAccountMap, newAccountMap);
  }

  // -------------------- AFTER UPDATE --------------------

  protected override void afterUpdate(
    List<SObject> newRecords,
    List<SObject> oldRecords,
    Map<Id, SObject> newRecordMap,
    Map<Id, SObject> oldRecordMap
  ) {
    List<Account> newAccountList = getAccountList(newRecords);
    Map<Id, Account> newAccountMap = getAccountMap(newRecordMap);
    Map<Id, Account> oldAccountMap = getAccountMap(oldRecordMap);

    updateContactPhoneFromAccount(newAccountMap, oldAccountMap);
  }

  // -------------------- BEFORE DELETE --------------------

  protected override void beforeDelete(
    List<SObject> oldRecords,
    Map<Id, SObject> oldRecordMap
  ) {
    List<Account> oldAccountList = getAccountList(oldRecords);

    for (Account accountRecord : oldAccountList) {
      // Example validation
      if (accountRecord.Name == 'Protected Account') {
        accountRecord.addError('This account cannot be deleted.');
      }
    }
  }

  // -------------------- AFTER DELETE --------------------

  protected override void afterDelete(
    List<SObject> oldRecords,
    Map<Id, SObject> oldRecordMap
  ) {
    List<Account> oldAccountList = getAccountList(oldRecords);

    for (Account deletedAccount : oldAccountList) {
      // Example logic
      System.debug('Deleted Account Id: ' + deletedAccount.Id);
    }
  }

  // -------------------- AFTER UNDELETE --------------------

  protected override void afterUndelete(
    List<SObject> newRecords,
    Map<Id, SObject> newRecordMap
  ) {
    List<Account> restoredAccountList = getAccountList(newRecords);
    Map<Id, Account> newAccountMap = getAccountMap(newRecordMap);

    duplicateSicValidation(restoredAccountList, null, newAccountMap);
  }

  /**
   * Updates contact phone numbers based on account phone number changes.
   * @param newAccountMap Map of new account records.
   * @param oldAccountMap Map of old account records.
   */
  private void updateContactPhoneFromAccount(
    Map<Id, Account> newAccountMap,
    Map<Id, Account> oldAccountMap
  ) {
    Set<Id> accountIdsToUpdate = new Set<Id>();

    for (Account newAcc : newAccountMap.values()) {
      Account oldAcc = oldAccountMap.get(newAcc.Id);

      if (oldAcc == null || newAcc.Phone == oldAcc.Phone) {
        continue;
      }

      accountIdsToUpdate.add(newAcc.Id);
    }

    if (accountIdsToUpdate.isEmpty())
      return;

    List<Contact> contactsList = [
      SELECT Id, AccountId
      FROM Contact
      WHERE AccountId IN :accountIdsToUpdate
    ];

    for (Contact con : contactsList) {
      Account acc = newAccountMap.get(con.AccountId);

      if (acc != null) {
        con.Phone = acc.Phone;
      }
    }

    if (!contactsList.isEmpty()) {
      update contactsList;
    }
  }

  private void duplicateSicValidation(
    List<Account> newList,
    Map<Id, Account> oldMap,
    Map<Id, Account> newMap
  ) {
    Set<String> sicCodes = new Set<String>();
    Map<String, Integer> txnCountMap = new Map<String, Integer>();

    // ---------------------------
    // Step 1: Collect + count (only new/changed)
    // ---------------------------
    for (Account acc : newList) {
      Account oldAcc = (oldMap != null) ? oldMap.get(acc.Id) : null;

      if (String.isBlank(acc.Sic))
        continue;

      // Only validate when new or changed
      if (oldAcc == null || acc.Sic != oldAcc.Sic) {
        sicCodes.add(acc.Sic);

        // Count duplicates in same transaction
        txnCountMap.put(
          acc.Sic,
          txnCountMap.containsKey(acc.Sic)
            ? txnCountMap.get(acc.Sic) + 1
            : 1
        );
      }
    }

    if (sicCodes.isEmpty())
      return;

    // ---------------------------
    // Step 2: Check DB duplicates (exclude self)
    // ---------------------------
    Set<String> duplicateFromDB = new Set<String>();

    for (AggregateResult ar : [
      SELECT Sic sic, COUNT(Id) cnt
      FROM Account
      WHERE Sic IN :sicCodes AND Id NOT IN :newMap.keySet()
      GROUP BY Sic
    ]) {
      if ((Integer) ar.get('cnt') > 0) {
        duplicateFromDB.add((String) ar.get('sic'));
      }
    }

    // ---------------------------
    // Step 3: Final validation
    // ---------------------------
    for (Account acc : newList) {
      if (String.isBlank(acc.Sic))
        continue;

      Boolean isTxnDuplicate =
        txnCountMap.containsKey(acc.Sic) &&
        txnCountMap.get(acc.Sic) > 1;

      Boolean isDbDuplicate = duplicateFromDB.contains(acc.Sic);

      if (isTxnDuplicate || isDbDuplicate) {
        acc.addError('Duplicate SIC Code not allowed: ' + acc.Sic);
      }
    }
  }
}
