public virtual class TriggerHandler {
  // -------------------- Context constants --------------------

  private static final String CONTEXT_BEFORE_INSERT = 'beforeInsert';
  private static final String CONTEXT_BEFORE_UPDATE = 'beforeUpdate';
  private static final String CONTEXT_BEFORE_DELETE = 'beforeDelete';
  private static final String CONTEXT_AFTER_INSERT = 'afterInsert';
  private static final String CONTEXT_AFTER_UPDATE = 'afterUpdate';
  private static final String CONTEXT_AFTER_DELETE = 'afterDelete';
  private static final String CONTEXT_AFTER_UNDELETE = 'afterUndelete';

  // -------------------- Context → Metadata Mapping --------------------

  private static final Map<String, String> CONTEXT_FIELD_MAP = new Map<String, String>{
    CONTEXT_BEFORE_INSERT => 'RunBeforeInsert__c',
    CONTEXT_BEFORE_UPDATE => 'RunBeforeUpdate__c',
    CONTEXT_BEFORE_DELETE => 'RunBeforeDelete__c',
    CONTEXT_AFTER_INSERT => 'RunAfterInsert__c',
    CONTEXT_AFTER_UPDATE => 'RunAfterUpdate__c',
    CONTEXT_AFTER_DELETE => 'RunAfterDelete__c',
    CONTEXT_AFTER_UNDELETE => 'RunAfterUndelete__c'
  };

  // -------------------- Static State --------------------

  private static Map<String, TriggerSetting__mdt> triggerSettingsCache;
  private static Set<String> bypassedObjects = new Set<String>();
  // Per-record recursion control: store processed keys of form object:context:recordId
  private static Set<String> processedKeys = new Set<String>();
  private static Set<String> loggedKeys = new Set<String>();

  private String objectName;

  // -------------------- Constructor --------------------

  public TriggerHandler() {
    if (Trigger.isExecuting) {
      // SAFE Apex way (NO Trigger.sObjectType dependency issues)
      if (Trigger.new != null && !Trigger.new.isEmpty()) {
        objectName = String.valueOf(Trigger.new[0].getSObjectType());
      } else if (Trigger.old != null && !Trigger.old.isEmpty()) {
        objectName = String.valueOf(Trigger.old[0].getSObjectType());
      }
    }

    loadTriggerSettings();
  }

  // -------------------- Entry Point --------------------

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
      String context = getCurrentContext();

      if (context == null || !isContextEnabled(context)) {
        logOnce('Disabled/unknown context: ' + context);
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

      // -------------------- BEFORE INSERT --------------------
      if (context == CONTEXT_BEFORE_INSERT) {
        beforeInsert(newList);
        return;
      }

      // -------------------- BEFORE UPDATE --------------------
      if (context == CONTEXT_BEFORE_UPDATE) {
        List<SObject> records = filterProcessedRecords(newList, context);
        if (!records.isEmpty()) {
          beforeUpdate(
            records,
            getFilteredOldRecords(records, oldMap),
            newMap,
            oldMap
          );
        }
        return;
      }

      // -------------------- BEFORE DELETE --------------------
      if (context == CONTEXT_BEFORE_DELETE) {
        List<SObject> records = filterProcessedRecords(oldList, context);
        if (!records.isEmpty()) {
          beforeDelete(records, oldMap);
        }
        return;
      }

      // -------------------- AFTER INSERT --------------------
      if (context == CONTEXT_AFTER_INSERT) {
        List<SObject> records = filterProcessedRecords(newList, context);
        if (!records.isEmpty()) {
          afterInsert(records, newMap);
        }
        return;
      }

      // -------------------- AFTER UPDATE --------------------
      if (context == CONTEXT_AFTER_UPDATE) {
        List<SObject> records = filterProcessedRecords(newList, context);
        if (!records.isEmpty()) {
          afterUpdate(
            records,
            getFilteredOldRecords(records, oldMap),
            newMap,
            oldMap
          );
        }
        return;
      }

      // -------------------- AFTER DELETE --------------------
      if (context == CONTEXT_AFTER_DELETE) {
        List<SObject> records = filterProcessedRecords(oldList, context);
        if (!records.isEmpty()) {
          afterDelete(records, oldMap);
        }
        return;
      }

      // -------------------- AFTER UNDELETE --------------------
      if (context == CONTEXT_AFTER_UNDELETE) {
        List<SObject> records = filterProcessedRecords(newList, context);
        if (!records.isEmpty()) {
          afterUndelete(records, newMap);
        }
        return;
      }
    } catch (Exception e) {
      logError('Trigger error [' + objectName + ']: ' + e.getMessage(), e);
      throw e;
    }
  }

  // -------------------- Context Resolver --------------------

  private String getCurrentContext() {
    if (Trigger.isBefore && Trigger.isInsert)
      return CONTEXT_BEFORE_INSERT;
    if (Trigger.isBefore && Trigger.isUpdate)
      return CONTEXT_BEFORE_UPDATE;
    if (Trigger.isBefore && Trigger.isDelete)
      return CONTEXT_BEFORE_DELETE;
    if (Trigger.isAfter && Trigger.isInsert)
      return CONTEXT_AFTER_INSERT;
    if (Trigger.isAfter && Trigger.isUpdate)
      return CONTEXT_AFTER_UPDATE;
    if (Trigger.isAfter && Trigger.isDelete)
      return CONTEXT_AFTER_DELETE;
    if (Trigger.isAfter && Trigger.isUndelete)
      return CONTEXT_AFTER_UNDELETE;
    return null;
  }

  // -------------------- Metadata --------------------

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
    return setting != null && setting.IsActive__c;
  }

  private Boolean isContextEnabled(String context) {
    TriggerSetting__mdt setting = getSetting();
    if (setting == null)
      return true;

    String fieldName = CONTEXT_FIELD_MAP.get(context);
    if (String.isBlank(fieldName))
      return true;

    Object val = setting.get(fieldName);
    return (val instanceof Boolean) ? (Boolean) val : true;
  }

  // -------------------- Recursion Control --------------------

  private List<SObject> filterProcessedRecords(
    List<SObject> records,
    String context
  ) {
    List<SObject> result = new List<SObject>();
    if (records == null || records.isEmpty())
      return result;

    // Per-record processed key approach (enterprise-grade):
    for (SObject record : records) {
      if (record == null || record.Id == null) {
        // Skip records without Id (e.g., before insert) — return all for beforeInsert caller
        continue;
      }
      String key = objectName + ':' + context + ':' + String.valueOf(record.Id);
      if (!processedKeys.contains(key)) {
        processedKeys.add(key);
        result.add(record);
      }
    }

    // If this is a context where records have no Id (before insert), return original list
    if (context == CONTEXT_BEFORE_INSERT) {
      return records;
    }

    return result;
  }

  private List<SObject> getFilteredOldRecords(
    List<SObject> newRecords,
    Map<Id, SObject> oldMap
  ) {
    List<SObject> oldRecords = new List<SObject>();

    for (SObject record : newRecords) {
      if (record.Id != null && oldMap.containsKey(record.Id)) {
        oldRecords.add(oldMap.get(record.Id));
      }
    }

    return oldRecords;
  }

  // -------------------- Logging --------------------

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

  // -------------------- Bypass --------------------

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

  // -------------------- Hooks --------------------

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
