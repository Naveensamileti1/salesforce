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

    for (Account accountRecord : newAccountList) {
      // Example logic
      if (String.isBlank(accountRecord.Name)) {
        accountRecord.Name = 'Default Account Name';
      }
    }
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

    for (Account newAccount : newAccountList) {
      Account oldAccount = oldAccountMap.get(newAccount.Id);

      if (oldAccount == null)
        continue;

      // Example: Name change detection
      if (newAccount.Name != oldAccount.Name) {
        System.debug(
          'Account name changed from ' +
            oldAccount.Name +
            ' to ' +
            newAccount.Name
        );
      }
    }
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

    for (Account newAccount : newAccountList) {
      Account oldAccount = oldAccountMap.get(newAccount.Id);

      if (oldAccount == null)
        continue;

      // Example logic
      if (newAccount.Industry != oldAccount.Industry) {
        System.debug('Industry updated for Account Id: ' + newAccount.Id);
      }
    }
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

    for (Account restoredAccount : restoredAccountList) {
      // Example logic
      System.debug('Restored Account Id: ' + restoredAccount.Id);
    }
  }
}
