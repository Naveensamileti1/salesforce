public class ContactTriggerHandler extends TriggerHandler {
  // -------------------- Type Helpers --------------------

  private List<Contact> getContactList(List<SObject> records) {
    return (List<Contact>) records;
  }

  private Map<Id, Contact> getContactMap(Map<Id, SObject> recordMap) {
    return (Map<Id, Contact>) recordMap;
  }

  // -------------------- BEFORE INSERT --------------------

  protected override void beforeInsert(List<SObject> newRecords) {
    List<Contact> newContactList = getContactList(newRecords);

    for (Contact contactRecord : newContactList) {
      // Example logic: ensure LastName exists
      if (String.isBlank(contactRecord.LastName)) {
        contactRecord.LastName = 'Unknown';
      }
    }
  }

  // -------------------- AFTER INSERT --------------------

  protected override void afterInsert(
    List<SObject> newRecords,
    Map<Id, SObject> newRecordMap
  ) {
    List<Contact> newContactList = getContactList(newRecords);
    Map<Id, Contact> newContactMap = getContactMap(newRecordMap);

    for (Contact contactRecord : newContactList) {
      Contact insertedContact = newContactMap.get(contactRecord.Id);

      // Example logic
      System.debug('Inserted Contact Id: ' + insertedContact.Id);
    }
  }

  // -------------------- BEFORE UPDATE --------------------

  protected override void beforeUpdate(
    List<SObject> newRecords,
    List<SObject> oldRecords,
    Map<Id, SObject> newRecordMap,
    Map<Id, SObject> oldRecordMap
  ) {
    List<Contact> newContactList = getContactList(newRecords);
    List<Contact> oldContactList = getContactList(oldRecords);
    Map<Id, Contact> oldContactMap = getContactMap(oldRecordMap);

    for (Contact newContact : newContactList) {
      Contact oldContact = oldContactMap.get(newContact.Id);

      if (oldContact == null)
        continue;

      // Example: detect AccountId change
      if (newContact.AccountId != oldContact.AccountId) {
        System.debug(
          'Contact Account changed from ' +
            oldContact.AccountId +
            ' to ' +
            newContact.AccountId
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
    List<Contact> newContactList = getContactList(newRecords);
    Map<Id, Contact> newContactMap = getContactMap(newRecordMap);
    Map<Id, Contact> oldContactMap = getContactMap(oldRecordMap);

    syncAccountDescriptionFromContacts(newContactMap, oldContactMap);
  }

  // -------------------- BEFORE DELETE --------------------

  protected override void beforeDelete(
    List<SObject> oldRecords,
    Map<Id, SObject> oldRecordMap
  ) {
    List<Contact> oldContactList = getContactList(oldRecords);

    for (Contact contactRecord : oldContactList) {
      // Example validation
      if (
        contactRecord.Email != null &&
        contactRecord.Email.endsWith('@example.com')
      ) {
        contactRecord.addError(
          'Contacts with example.com email cannot be deleted.'
        );
      }
    }
  }

  // -------------------- AFTER DELETE --------------------

  protected override void afterDelete(
    List<SObject> oldRecords,
    Map<Id, SObject> oldRecordMap
  ) {
    List<Contact> oldContactList = getContactList(oldRecords);

    for (Contact deletedContact : oldContactList) {
      // Example logic
      System.debug('Deleted Contact Id: ' + deletedContact.Id);
    }
  }

  // -------------------- AFTER UNDELETE --------------------

  protected override void afterUndelete(
    List<SObject> newRecords,
    Map<Id, SObject> newRecordMap
  ) {
    List<Contact> restoredContactList = getContactList(newRecords);

    for (Contact restoredContact : restoredContactList) {
      // Example logic
      System.debug('Restored Contact Id: ' + restoredContact.Id);
    }
  }

  private void syncAccountDescriptionFromContacts(
    Map<Id, Contact> newContactMap,
    Map<Id, Contact> oldContactMap
  ) {
    Map<Id, String> accountToTextMap = new Map<Id, String>();

    for (Contact newCon : newContactMap.values()) {
      Contact oldCon = oldContactMap.get(newCon.Id);

      if (oldCon == null || newCon.AccountId == null)
        continue;

      if (newCon.Description == oldCon.Description)
        continue;

      String entry =
        '\n[Contact Update]' +
        '\nContact Id: ' +
        newCon.Id +
        '\nOld Description: ' +
        String.valueOf(oldCon.Description) +
        '\nNew Description: ' +
        String.valueOf(newCon.Description) +
        '\n-------------------------\n';

      String existing = accountToTextMap.get(newCon.AccountId);
      if (existing == null)
        existing = '';

      accountToTextMap.put(newCon.AccountId, existing + entry);
    }

    if (accountToTextMap.isEmpty())
      return;

    List<Account> accountsToUpdate = [
      SELECT Id, Description
      FROM Account
      WHERE Id IN :accountToTextMap.keySet()
    ];

    for (Account acc : accountsToUpdate) {
      String existing = acc.Description == null ? '' : acc.Description;
      String appendText = accountToTextMap.get(acc.Id);

      String combined = existing + appendText;

      if (combined.length() > 32000) {
        combined = combined.substring(combined.length() - 32000);
      }

      acc.Description = combined;
    }

    update accountsToUpdate;
  }
}
