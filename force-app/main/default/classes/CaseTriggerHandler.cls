public class CaseTriggerHandler extends TriggerHandler {
  // -------------------- Type Helpers --------------------

  public List<Case> getCaseList(List<SObject> records) {
    return (List<Case>) records;
  }

  public Map<Id, Case> getCaseMap(Map<Id, SObject> recordMap) {
    return (Map<Id, Case>) recordMap;
  }

  // -------------------- BEFORE INSERT --------------------

  protected override void beforeInsert(List<SObject> newRecords) {
    List<Case> newCases = getCaseList(newRecords);
    for (Case c : newCases) {
      // Example: ensure Subject is set
      if (String.isBlank(c.Subject)) {
        c.Subject = 'No Subject';
      }
    }

    // Update latest case info on account for insert
    latestCaseOnAccount(newCases, null, getCaseMap(Trigger.newMap), null);
  }

  // -------------------- AFTER INSERT --------------------

  protected override void afterInsert(
    List<SObject> newRecords,
    Map<Id, SObject> newMap
  ) {
    List<Case> newCases = getCaseList(newRecords);
    Map<Id, Case> newCaseMap = getCaseMap(newMap);

    // Placeholder for post-insert logic; keep minimal and safe
    for (Case c : newCases) {
      System.debug('Case inserted: ' + c.Id + ' Subject: ' + c.Subject);
    }

    // Update latest case info on account for after insert as well
    latestCaseOnAccount(newCases, null, newCaseMap, null);
  }

  // -------------------- BEFORE UPDATE --------------------

  protected override void beforeUpdate(
    List<SObject> newRecords,
    List<SObject> oldRecords,
    Map<Id, SObject> newMap,
    Map<Id, SObject> oldMap
  ) {
    List<Case> newCases = getCaseList(newRecords);
    List<Case> oldCases = getCaseList(oldRecords);
    Map<Id, Case> newCaseMap = getCaseMap(newMap);
    Map<Id, Case> oldCaseMap = getCaseMap(oldMap);

    for (Case newC : newCases) {
      Case oldC = oldCaseMap.get(newC.Id);
      if (oldC == null)
        continue;

      // Example: detect Status change
      if (newC.Status != oldC.Status) {
        System.debug(
          'Case Status changed from ' +
            oldC.Status +
            ' to ' +
            newC.Status +
            ' for Case Id: ' +
            newC.Id
        );
      }
    }

    // Update latest case info on account for update
    latestCaseOnAccount(newCases, oldCases, newCaseMap, oldCaseMap);
  }

  // -------------------- AFTER UPDATE --------------------

  protected override void afterUpdate(
    List<SObject> newRecords,
    List<SObject> oldRecords,
    Map<Id, SObject> newMap,
    Map<Id, SObject> oldMap
  ) {
    List<Case> newCases = getCaseList(newRecords);
    List<Case> oldCases = getCaseList(oldRecords);
    Map<Id, Case> newCaseMap = getCaseMap(newMap);
    Map<Id, Case> oldCaseMap = getCaseMap(oldMap);

    // Placeholder for post-update logic
    for (Case c : newCases) {
      System.debug('Case updated: ' + c.Id);
    }
  }

  // -------------------- BEFORE DELETE --------------------

  protected override void beforeDelete(
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap
  ) {
    List<Case> oldCases = getCaseList(oldRecords);
    for (Case c : oldCases) {
      // Example validation: prevent deletion of high priority cases
      if (c.Priority == 'High') {
        c.addError('High priority cases cannot be deleted.');
      }
    }
  }

  // -------------------- AFTER DELETE --------------------

  protected override void afterDelete(
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap
  ) {
    List<Case> oldCases = getCaseList(oldRecords);
    for (Case c : oldCases) {
      System.debug('Case deleted: ' + c.Id);
    }
  }

  // -------------------- AFTER UNDELETE --------------------

  protected override void afterUndelete(
    List<SObject> newRecords,
    Map<Id, SObject> newMap
  ) {
    List<Case> restoredCases = getCaseList(newRecords);
    for (Case c : restoredCases) {
      System.debug('Case undeleted: ' + c.Id);
    }

    // Update latest case info on account for undelete
    latestCaseOnAccount(restoredCases, null, getCaseMap(newMap), null);
  }

  private void latestCaseOnAccount(
    List<Case> newList,
    List<Case> oldList,
    Map<Id, Case> newMap,
    Map<Id, Case> oldMap
  ) {
    Set<Id> accountIds = new Set<Id>();

    // INSERT / UPDATE / UNDELETE: newList may be null
    if (newList != null) {
      for (Case c : newList) {
        if (c.AccountId != null) {
          accountIds.add(c.AccountId);
        }

        Case oldC = (oldMap != null) ? oldMap.get(c.Id) : null;
        if (
          oldC != null &&
          oldC.AccountId != null &&
          oldC.AccountId != c.AccountId
        ) {
          accountIds.add(oldC.AccountId);
        }
      }
    }

    // DELETE: oldList may be null
    if (oldList != null) {
      for (Case c : oldList) {
        if (c.AccountId != null) {
          accountIds.add(c.AccountId);
        }
      }
    }

    if (accountIds.isEmpty()) {
      return;
    }

    // Query latest case per account via subquery
    List<Account> accounts = [
      SELECT
        Id,
        Latest_Case__c,
        (SELECT Id, CreatedDate FROM Cases ORDER BY CreatedDate DESC LIMIT 1)
      FROM Account
      WHERE Id IN :accountIds
    ];

    List<Account> toUpdate = new List<Account>();

    for (Account acc : accounts) {
      Id latestCaseId = null;
      if (acc.Cases != null && !acc.Cases.isEmpty()) {
        latestCaseId = acc.Cases[0].Id;
      }

      Id current = acc.Latest_Case__c;
      if (current == null && latestCaseId == null) {
        continue;
      }

      if (
        (current == null && latestCaseId != null) ||
        (current != null &&
        current != latestCaseId)
      ) {
        toUpdate.add(new Account(Id = acc.Id, Latest_Case__c = latestCaseId));
      }
    }

    if (!toUpdate.isEmpty()) {
      update toUpdate;
    }
  }
}
