public virtual class TriggerHandler {
  // -------------------- Context constants --------------------

  private static final String CONTEXT_BEFORE_INSERT = 'beforeInsert';
  private static final String CONTEXT_BEFORE_UPDATE = 'beforeUpdate';
  private static final String CONTEXT_BEFORE_DELETE = 'beforeDelete';
  private static final String CONTEXT_AFTER_INSERT = 'afterInsert';
  private static final String CONTEXT_AFTER_UPDATE = 'afterUpdate';
  private static final String CONTEXT_AFTER_DELETE = 'afterDelete';
  private static final String CONTEXT_AFTER_UNDELETE = 'afterUndelete';

  // -------------------- Context → Metadata Field Map --------------------

  private static final Map<String, String> CONTEXT_FIELD_MAP = new Map<String, String>{
    CONTEXT_BEFORE_INSERT => 'RunBeforeInsert__c',
    CONTEXT_BEFORE_UPDATE => 'RunBeforeUpdate__c',
    CONTEXT_BEFORE_DELETE => 'RunBeforeDelete__c',
    CONTEXT_AFTER_INSERT => 'RunAfterInsert__c',
    CONTEXT_AFTER_UPDATE => 'RunAfterUpdate__c',
    CONTEXT_AFTER_DELETE => 'RunAfterDelete__c',
    CONTEXT_AFTER_UNDELETE => 'RunAfterUndelete__c'
  };

  // -------------------- Static state --------------------

  private static Map<String, TriggerSetting__mdt> triggerSettingsCache;
  private static Set<String> bypassedObjects = new Set<String>();
  private static Map<String, Set<Id>> processedRecords = new Map<String, Set<Id>>();
  private static Set<String> loggedKeys = new Set<String>();

  private String objectName;

  // -------------------- Constructor --------------------

  public TriggerHandler() {
    if (Trigger.new != null && !Trigger.new.isEmpty()) {
      this.objectName = Trigger.new[0].getSObjectType().getDescribe().getName();
    } else if (Trigger.old != null && !Trigger.old.isEmpty()) {
      this.objectName = Trigger.old[0].getSObjectType().getDescribe().getName();
    }
    loadTriggerSettings();
  }

  // -------------------- Entry Point --------------------

  public void run() {
    // ✅ Correct guard
    if (!Trigger.isExecuting) {
      System.debug(LoggingLevel.WARN, 'TriggerHandler called outside trigger');
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

      if (CONTEXT_BEFORE_INSERT.equals(context)) {
        beforeInsert(newList);
        return;
      }

      if (CONTEXT_BEFORE_UPDATE.equals(context)) {
        List<SObject> newRecords = filterProcessedRecords(newList, context);
        if (!newRecords.isEmpty()) {
          beforeUpdate(
            newRecords,
            getFilteredOldRecords(newRecords, oldMap),
            newMap,
            oldMap
          );
        }
        return;
      }

      if (CONTEXT_BEFORE_DELETE.equals(context)) {
        List<SObject> oldRecords = filterProcessedRecords(oldList, context);
        if (!oldRecords.isEmpty()) {
          beforeDelete(oldRecords, oldMap);
        }
        return;
      }

      if (CONTEXT_AFTER_INSERT.equals(context)) {
        List<SObject> newRecords = filterProcessedRecords(newList, context);
        if (!newRecords.isEmpty()) {
          afterInsert(newRecords, newMap);
        }
        return;
      }

      if (CONTEXT_AFTER_UPDATE.equals(context)) {
        List<SObject> newRecords = filterProcessedRecords(newList, context);
        if (!newRecords.isEmpty()) {
          afterUpdate(
            newRecords,
            getFilteredOldRecords(newRecords, oldMap),
            newMap,
            oldMap
          );
        }
        return;
      }

      if (CONTEXT_AFTER_DELETE.equals(context)) {
        List<SObject> oldRecords = filterProcessedRecords(oldList, context);
        if (!oldRecords.isEmpty()) {
          afterDelete(oldRecords, oldMap);
        }
        return;
      }

      if (CONTEXT_AFTER_UNDELETE.equals(context)) {
        List<SObject> newRecords = filterProcessedRecords(newList, context);
        if (!newRecords.isEmpty()) {
          afterUndelete(newRecords, newMap);
        }
        return;
      }

      logOnce('Unhandled context: ' + context);
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

      try {
        for (
          TriggerSetting__mdt setting : TriggerSetting__mdt.getAll().values()
        ) {
          if (String.isNotBlank(setting.ObjectName__c)) {
            triggerSettingsCache.put(setting.ObjectName__c, setting);
          }
        }
      } catch (Exception e) {
        System.debug(
          LoggingLevel.ERROR,
          'Error loading trigger settings: ' + e.getMessage()
        );
        triggerSettingsCache = new Map<String, TriggerSetting__mdt>();
      }
    }
  }

  private TriggerSetting__mdt getSetting() {
    return (triggerSettingsCache != null &&
      objectName != null)
      ? triggerSettingsCache.get(objectName)
      : null;
  }

  private Boolean isTriggerActive() {
    TriggerSetting__mdt setting = getSetting();

    if (setting == null) {
      logOnce('Trigger disabled (no metadata): ' + objectName);
      return false;
    }

    return setting.IsActive__c;
  }

  private Boolean isContextEnabled(String context) {
    TriggerSetting__mdt setting = getSetting();
    if (setting == null)
      return true;

    String fieldName = CONTEXT_FIELD_MAP.get(context);
    if (String.isBlank(fieldName))
      return true;

    try {
      Object val = setting.get(fieldName);
      return (val instanceof Boolean) ? (Boolean) val : true;
    } catch (Exception e) {
      return true;
    }
  }

  // -------------------- Recursion Control --------------------

  private List<SObject> filterProcessedRecords(
    List<SObject> records,
    String context
  ) {
    List<SObject> result = new List<SObject>();
    if (records == null || records.isEmpty())
      return result;

    String handlerName = String.valueOf(this).split(':')[0];
    String key =
      handlerName +
      '_' +
      objectName +
      '_' +
      context +
      '_' +
      Request.getCurrent().getRequestId();

    Set<Id> processed = processedRecords.get(key);
    if (processed == null) {
      processed = new Set<Id>();
      processedRecords.put(key, processed);
    }

    for (SObject rec : records) {
      if (rec == null)
        continue;

      if (rec.Id == null || !processed.contains(rec.Id)) {
        result.add(rec);
        if (rec.Id != null)
          processed.add(rec.Id);
      }
    }

    return result;
  }

  private List<SObject> getFilteredOldRecords(
    List<SObject> newRecords,
    Map<Id, SObject> oldMap
  ) {
    List<SObject> oldRecords = new List<SObject>();
    if (newRecords == null || oldMap == null)
      return oldRecords;

    for (SObject rec : newRecords) {
      if (rec != null && rec.Id != null) {
        SObject oldRec = oldMap.get(rec.Id);
        if (oldRec != null)
          oldRecords.add(oldRec);
      }
    }

    return oldRecords;
  }

  // -------------------- Logging --------------------

  private void logOnce(String msg) {
    String handlerName = String.valueOf(this).split(':')[0];
    String key =
      handlerName +
      '_' +
      objectName +
      '_' +
      msg +
      '_' +
      Request.getCurrent().getRequestId();

    if (!loggedKeys.contains(key)) {
      loggedKeys.add(key);
      System.debug(LoggingLevel.WARN, msg);
    }
  }

  private void logError(String msg, Exception e) {
    System.debug(LoggingLevel.ERROR, msg);
    System.debug(LoggingLevel.ERROR, e.getStackTraceString());
  }

  // -------------------- Bypass --------------------

  private Boolean isBypassed() {
    return objectName != null && bypassedObjects.contains(objectName);
  }

  public static void bypass(String objectName) {
    if (objectName != null)
      bypassedObjects.add(objectName);
  }

  public static void clearBypass(String objectName) {
    if (objectName != null)
      bypassedObjects.remove(objectName);
  }

  public static void clearAllBypasses() {
    bypassedObjects.clear();
  }

  @TestVisible
  private static void resetAll() {
    triggerSettingsCache = null;
    bypassedObjects.clear();
    processedRecords.clear();
    loggedKeys.clear();
  }

  // -------------------- Hooks --------------------

  protected virtual void beforeInsert(List<SObject> newRecords) {
  }
  protected virtual void afterInsert(
    List<SObject> newRecords,
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
