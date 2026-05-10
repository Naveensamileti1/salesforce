public virtual class TriggerHandler {
  // -----------------------------------
  // Context → Metadata Mapping
  // -----------------------------------

  private static final Map<System.TriggerOperation, String> CONTEXT_FIELD_MAP = new Map<System.TriggerOperation, String>{
    System.TriggerOperation.BEFORE_INSERT => 'RunBeforeInsert__c',
    System.TriggerOperation.BEFORE_UPDATE => 'RunBeforeUpdate__c',
    System.TriggerOperation.BEFORE_DELETE => 'RunBeforeDelete__c',
    System.TriggerOperation.AFTER_INSERT => 'RunAfterInsert__c',
    System.TriggerOperation.AFTER_UPDATE => 'RunAfterUpdate__c',
    System.TriggerOperation.AFTER_DELETE => 'RunAfterDelete__c',
    System.TriggerOperation.AFTER_UNDELETE => 'RunAfterUndelete__c'
  };

  // -----------------------------------
  // Static State
  // -----------------------------------

  private static Map<String, TriggerSetting__mdt> triggerSettingsCache;

  private static Set<String> bypassedObjects = new Set<String>();

  private static Map<String, Set<Id>> processedByContext = new Map<String, Set<Id>>();

  private static Set<String> loggedKeys = new Set<String>();

  private String objectName;

  // -----------------------------------
  // Constructor
  // -----------------------------------

  public TriggerHandler() {
    if (!Trigger.isExecuting) {
      return;
    }

    if (Trigger.new != null && !Trigger.new.isEmpty()) {
      objectName = Trigger.new[0].getSObjectType().getDescribe().getName();
    } else if (Trigger.old != null && !Trigger.old.isEmpty()) {
      objectName = Trigger.old[0].getSObjectType().getDescribe().getName();
    }

    loadTriggerSettings();
  }

  // -----------------------------------
  // Entry Point
  // -----------------------------------

  public void run() {
    if (!Trigger.isExecuting || String.isBlank(objectName)) {
      System.debug(
        LoggingLevel.WARN,
        'TriggerHandler executed outside trigger'
      );

      return;
    }

    if (isBypassed() || !isTriggerActive()) {
      return;
    }

    try {
      System.TriggerOperation context = Trigger.operationType;

      if (context == null || !isContextEnabled(context)) {
        logOnce('Disabled/unknown context: ' + String.valueOf(context));

        return;
      }

      List<SObject> newList = Trigger.new != null
        ? Trigger.new
        : new List<SObject>();

      List<SObject> oldList = Trigger.old != null
        ? Trigger.old
        : new List<SObject>();

      Map<Id, SObject> newMap = Trigger.newMap != null
        ? Trigger.newMap
        : new Map<Id, SObject>();

      Map<Id, SObject> oldMap = Trigger.oldMap != null
        ? Trigger.oldMap
        : new Map<Id, SObject>();

      // -----------------------------------
      // Trigger Context Routing
      // -----------------------------------

      switch on context {
        // ---------------- BEFORE INSERT ----------------

        when BEFORE_INSERT {
          beforeInsert(newList);
        }
        // ---------------- BEFORE UPDATE ----------------

        when BEFORE_UPDATE {
          List<SObject> records = filterProcessedRecords(newList, context);

          if (!records.isEmpty()) {
            beforeUpdate(
              records,
              getFilteredOldRecords(records, oldMap),
              newMap,
              oldMap
            );
          }
        }
        // ---------------- BEFORE DELETE ----------------

        when BEFORE_DELETE {
          List<SObject> records = filterProcessedRecords(oldList, context);

          if (!records.isEmpty()) {
            beforeDelete(records, oldMap);
          }
        }
        // ---------------- AFTER INSERT ----------------

        when AFTER_INSERT {
          List<SObject> records = filterProcessedRecords(newList, context);

          if (!records.isEmpty()) {
            afterInsert(records, newMap);
          }
        }
        // ---------------- AFTER UPDATE ----------------

        when AFTER_UPDATE {
          List<SObject> records = filterProcessedRecords(newList, context);

          if (!records.isEmpty()) {
            afterUpdate(
              records,
              getFilteredOldRecords(records, oldMap),
              newMap,
              oldMap
            );
          }
        }
        // ---------------- AFTER DELETE ----------------

        when AFTER_DELETE {
          List<SObject> records = filterProcessedRecords(oldList, context);

          if (!records.isEmpty()) {
            afterDelete(records, oldMap);
          }
        }
        // ---------------- AFTER UNDELETE ----------------

        when AFTER_UNDELETE {
          List<SObject> records = filterProcessedRecords(newList, context);

          if (!records.isEmpty()) {
            afterUndelete(records, newMap);
          }
        }
      }
    } catch (Exception e) {
      logError('Trigger error [' + objectName + ']: ' + e.getMessage(), e);

      throw e;
    }
  }

  // -----------------------------------
  // Metadata
  // -----------------------------------

  private static void loadTriggerSettings() {
    if (triggerSettingsCache == null) {
      triggerSettingsCache = new Map<String, TriggerSetting__mdt>();

      for (
        TriggerSetting__mdt setting : TriggerSetting__mdt.getAll().values()
      ) {
        if (String.isNotBlank(setting.ObjectName__c)) {
          triggerSettingsCache.put(setting.ObjectName__c, setting);
        }
      }
    }
  }

  private TriggerSetting__mdt getSetting() {
    return triggerSettingsCache != null
      ? triggerSettingsCache.get(objectName)
      : null;
  }

  private Boolean isTriggerActive() {
    TriggerSetting__mdt setting = getSetting();

    return setting != null || setting.IsActive__c;
  }

  private Boolean isContextEnabled(System.TriggerOperation context) {
    TriggerSetting__mdt setting = getSetting();

    if (setting == null) {
      return true;
    }

    String fieldName = CONTEXT_FIELD_MAP.get(context);

    if (String.isBlank(fieldName)) {
      return true;
    }

    Object val = setting.get(fieldName);

    return (val instanceof Boolean) ? (Boolean) val : true;
  }

  // -----------------------------------
  // Recursion Control
  // -----------------------------------

  private List<SObject> filterProcessedRecords(
    List<SObject> records,
    System.TriggerOperation context
  ) {
    List<SObject> result = new List<SObject>();

    if (records == null || records.isEmpty()) {
      return result;
    }

    // BEFORE INSERT has no IDs yet
    if (context == System.TriggerOperation.BEFORE_INSERT) {
      return records;
    }

    String contextKey = objectName + '_' + String.valueOf(context);

    if (!processedByContext.containsKey(contextKey)) {
      processedByContext.put(contextKey, new Set<Id>());
    }

    Set<Id> processedIds = processedByContext.get(contextKey);

    for (SObject record : records) {
      if (record == null || record.Id == null) {
        continue;
      }

      if (!processedIds.contains(record.Id)) {
        processedIds.add(record.Id);

        result.add(record);
      }
    }

    return result;
  }

  private List<SObject> getFilteredOldRecords(
    List<SObject> newRecords,
    Map<Id, SObject> oldMap
  ) {
    List<SObject> oldRecords = new List<SObject>();

    if (newRecords == null || oldMap == null) {
      return oldRecords;
    }

    for (SObject record : newRecords) {
      if (record.Id != null && oldMap.containsKey(record.Id)) {
        oldRecords.add(oldMap.get(record.Id));
      }
    }

    return oldRecords;
  }

  // -----------------------------------
  // Logging
  // -----------------------------------

  private void logOnce(String message) {
    String key = 'TriggerHandler_' + objectName + '_' + message;

    if (!loggedKeys.contains(key)) {
      loggedKeys.add(key);

      System.debug(LoggingLevel.WARN, message);
    }
  }

  private void logError(String message, Exception e) {
    System.debug(LoggingLevel.ERROR, message);

    System.debug(LoggingLevel.ERROR, e.getStackTraceString());
  }

  // -----------------------------------
  // Bypass
  // -----------------------------------

  private Boolean isBypassed() {
    return bypassedObjects.contains(objectName);
  }

  public static void bypass(String objectName) {
    bypassedObjects.add(objectName);
  }

  public static void clearBypass(String objectName) {
    bypassedObjects.remove(objectName);
  }

  public static void clearAllBypasses() {
    bypassedObjects.clear();
  }

  // -----------------------------------
  // Hooks
  // -----------------------------------

  protected virtual void beforeInsert(List<SObject> records) {
  }

  protected virtual void afterInsert(
    List<SObject> records,
    Map<Id, SObject> newMap
  ) {
  }

  protected virtual void beforeUpdate(
    List<SObject> newRecords,
    List<SObject> oldRecords,
    Map<Id, SObject> newMap,
    Map<Id, SObject> oldMap
  ) {
  }

  protected virtual void afterUpdate(
    List<SObject> newRecords,
    List<SObject> oldRecords,
    Map<Id, SObject> newMap,
    Map<Id, SObject> oldMap
  ) {
  }

  protected virtual void beforeDelete(
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap
  ) {
  }

  protected virtual void afterDelete(
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap
  ) {
  }

  protected virtual void afterUndelete(
    List<SObject> newRecords,
    Map<Id, SObject> newMap
  ) {
  }
}
