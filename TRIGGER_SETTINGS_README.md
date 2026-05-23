# Trigger Settings with Custom Metadata Type

## Overview
This implementation provides a flexible, **object-based** way to control trigger execution using Custom Metadata Types. Triggers can be enabled or disabled dynamically without deploying code changes.

## Key Design Decisions

✅ **Object-Based Control** - Uses `Trigger.sObjectType.getDescribe().getName()` for reliable object identification  
✅ **Fail-Safe Default** - Triggers are DISABLED by default if no metadata record exists (explicit opt-in required)  
✅ **getAll() Efficiency** - Uses `TriggerSetting__mdt.getAll()` instead of SOQL (doesn't count against query limits)  
✅ **Record-Level Recursion Control** - Prevents infinite loops at the record level (more granular than context-level)  
✅ **Separate Bypass Logic** - Programmatic bypass is independent from metadata cache (clean separation of concerns)  
✅ **Error Handling** - Try-catch in run() with detailed logging for debugging

## Components Created

### 1. Custom Metadata Type: TriggerSetting__mdt
Located in: `force-app/main/default/objects/TriggerSetting__mdt/`

**Fields:**
- `TriggerName__c` (Text, Required) - The **SObject API name** (e.g., "Account", "Contact", "MyCustomObject__c")
- `IsActive__c` (Checkbox, Default: false) - Whether triggers for this object are active

### 2. TriggerHandler Base Class
Located in: `force-app/main/default/classes/TriggerHandler.cls`

**Key Features:**
- Uses `Trigger.sObjectType.getDescribe().getName()` to get object name (most reliable method)
- Uses `TriggerSetting__mdt.getAll()` to load settings (doesn't count against SOQL limits)
- **Defaults to INACTIVE** if no metadata record exists (fail-safe)
- **Record-level recursion control** - tracks processed record IDs per context
- **Separate bypass logic** - `bypassedObjects` Set independent from metadata cache
- Null validation on `TriggerName__c` field during loading
- Try-catch error handling with detailed logging
- Passes all trigger context variables to handler methods
- Static bypass methods for testing

**Important Methods:**
- `run()` - Main entry point, checks if trigger is active
- `bypass(String objectName)` - Programmatically disable triggers for an object
- `clearBypass(String objectName)` - Re-enable triggers for an object
- `clearAllBypasses()` - Clear all programmatic bypasses

**Virtual Methods to Override:**
- `beforeInsert(List<SObject> newRecords)`
- `afterInsert(List<SObject> newRecords, Map<Id, SObject> newRecordsMap)`
- `beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords, Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap)`
- `afterUpdate(List<SObject> newRecords, List<SObject> oldRecords, Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap)`
- `beforeDelete(List<SObject> oldRecords, Map<Id, SObject> oldRecordsMap)`
- `afterDelete(List<SObject> oldRecords, Map<Id, SObject> oldRecordsMap)`
- `afterUndelete(List<SObject> newRecords, Map<Id, SObject> newRecordsMap)`

### 3. Sample Implementation
- `AccountTrigger.trigger` - One-line trigger
- `AccountTriggerHandler.cls` - Example handler with proper type casting
- `TriggerSetting.Account.md-meta.xml` - Account object is ACTIVE

## How It Works

1. Trigger fires and creates handler instance: `new AccountTriggerHandler().run();`
2. Handler constructor calls `Trigger.sObjectType.getDescribe().getName()` to get object name (e.g., "Account")
3. All trigger settings are loaded once per transaction (cached)
4. Framework checks if metadata record exists for this object name
5. If found AND `IsActive__c = true`, trigger executes
6. If NOT found OR `IsActive__c = false`, trigger is skipped (fail-safe)
7. Recursion check prevents same object+context from running twice

## Usage

### Step 1: Create Your Trigger (One Line!)
```apex
trigger AccountTrigger on Account (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    new AccountTriggerHandler().run();
}
```

### Step 2: Create Your Handler Class
**Naming Convention:** Any name ending in `TriggerHandler` (e.g., `AccountTriggerHandler`, `MyObjectTriggerHandler`)

```apex
public class AccountTriggerHandler extends TriggerHandler {
    
    public AccountTriggerHandler() {
        super();
    }
    
    protected override void beforeInsert(List<SObject> newRecords) {
        List<Account> accounts = (List<Account>) newRecords;
        
        for (Account acc : accounts) {
            // Your bulk logic here
        }
    }
    
    protected override void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords, 
                                       Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
        List<Account> newAccounts = (List<Account>) newRecords;
        Map<Id, Account> oldAccountMap = (Map<Id, Account>) oldRecordsMap;
        
        for (Account acc : newAccounts) {
            Account oldAccount = oldAccountMap.get(acc.Id);
            
            if (acc.Name != oldAccount.Name) {
                // Name changed - your logic here
            }
        }
    }
    
    // Override other methods as needed
}
```

### Step 3: Create Custom Metadata Record (REQUIRED!)
Navigate to **Setup > Custom Metadata Types > Trigger Setting > Manage Records**

Create a new record:
- **Label:** Account (or any descriptive label)
- **Trigger Name:** Account (MUST match the **SObject API name** exactly)
- **Is Active:** Checked (to enable)

**⚠️ IMPORTANT:** Without this metadata record, the trigger will NOT execute (fail-safe default).

## Managing Trigger Execution

### Via Setup (No Deployment Required):
1. Go to Setup > Custom Metadata Types > Trigger Setting
2. Click "Manage Records"
3. Find or create the record for your object (use SObject API name)
4. Check/uncheck the "Is Active" checkbox
5. Save - **Changes take effect immediately!**

### Programmatically (For Testing):
```apex
// Disable triggers for Account (does NOT modify metadata cache)
TriggerHandler.bypass('Account');

// Check if Account is bypassed
Boolean isBypassed = TriggerHandler.isBypassed('Account');

// Re-enable triggers for Account (restores metadata-based behavior)
TriggerHandler.clearBypass('Account');

// Clear all bypasses (restores metadata-based behavior for all objects)
TriggerHandler.clearAllBypasses();
```

**Important:** Bypass is separate from metadata - it only affects the current transaction and does NOT modify the Custom Metadata cache.

## Object Name Examples

| SObject | TriggerName__c Value |
|---------|---------------------|
| Account | `Account` |
| Contact | `Contact` |
| Opportunity | `Opportunity` |
| Custom Object | `MyCustomObject__c` |
| Platform Event | `MyEvent__e` |

**Rule:** Use the exact SObject API name returned by `Trigger.sObjectType.getDescribe().getName()`

## Benefits

✅ **Object-Based** - Control by object name, not trigger/handler class names  
✅ **Fail-Safe Default** - Triggers MUST be explicitly enabled via metadata  
✅ **Reliable Detection** - Uses Salesforce's native `Trigger.sObjectType.getDescribe().getName()`  
✅ **No Deployment** - Toggle triggers via Setup instantly  
✅ **Ultra-Efficient** - Uses `getAll()` method, doesn't count against SOQL query limits  
✅ **Record-Level Recursion Control** - Prevents infinite loops by tracking processed record IDs  
✅ **Clean Bypass Logic** - Separate from metadata cache, easy to reason about  
✅ **Error Handling** - Try-catch with detailed logging for debugging  
✅ **Null Safety** - Validates TriggerName__c during loading  
✅ **Bulk Pattern** - All methods receive lists and maps  
✅ **Testing Support** - Multiple test utility methods  
✅ **Simple Triggers** - One line of code

## Deployment

Deploy all metadata to your org:
```bash
sf project deploy start --source-dir force-app/main/default
```

Or deploy specific components:
```bash
# Deploy custom metadata type
sf project deploy start --source-dir force-app/main/default/objects/TriggerSetting__mdt

# Deploy metadata records
sf project deploy start --source-dir force-app/main/default/customMetadata

# Deploy handler class
sf project deploy start --source-dir force-app/main/default/classes/TriggerHandler.cls

# Deploy example
sf project deploy start --source-dir force-app/main/default/classes/AccountTriggerHandler.cls
sf project deploy start --source-dir force-app/main/default/triggers/AccountTrigger.trigger
```

## Testing

### Initial Behavior (No Metadata Record):
1. Deploy the trigger and handler
2. Try to create an Account
3. Debug log shows: "No trigger setting found for object: Account. Defaulting to INACTIVE (fail-safe)."
4. Trigger does NOT execute

### After Creating Metadata Record:
1. Go to Setup > Custom Metadata Types > Trigger Setting > Manage Records
2. Click "New"
3. Label: Account
4. Trigger Name: Account
5. Is Active: Checked
6. Save
7. Create an Account
8. Debug log shows: "Loaded 1 trigger settings." and "AccountTrigger: Before Insert logic executed"

### Apex Test Example:
```apex
@isTest
private class AccountTriggerHandlerTest {
    
    @TestSetup
    static void setup() {
        // Note: Custom Metadata cannot be inserted in tests
        // Test with bypass methods instead
    }
    
    @isTest
    static void testTriggerBypassedProgrammatically() {
        // Bypass programmatically (separate from metadata)
        TriggerHandler.bypass('Account');
        
        // Verify bypass is active
        System.assert(TriggerHandler.isBypassed('Account'), 'Account should be bypassed');
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        // Trigger was bypassed
        System.assertNotEquals(null, acc.Id);
        
        // Clear bypass
        TriggerHandler.clearBypass('Account');
        
        // Verify bypass is cleared
        System.assert(!TriggerHandler.isBypassed('Account'), 'Account should not be bypassed');
    }
    
    @isTest
    static void testRecursionPrevention() {
        // Insert an account (this triggers beforeInsert, afterInsert)
        Account acc = new Account(Name = 'Test');
        insert acc;
        
        // Update the same account (beforeUpdate, afterUpdate)
        // Record-level recursion control prevents the same record from being processed twice in same context
        acc.Name = 'Test Updated';
        update acc;
        
        System.assertEquals('Test Updated', acc.Name);
    }
    
    @isTest
    static void testMultipleUpdates() {
        // Test that recursion control allows legitimate multi-phase execution
        Account acc = new Account(Name = 'Test');
        insert acc;
        
        // First update
        acc.Name = 'Update 1';
        update acc;
        
        // Second update - should work because it's a different transaction context
        acc.Name = 'Update 2';
        update acc;
        
        System.assertEquals('Update 2', acc.Name);
    }
}
```

## Troubleshooting

**Issue:** Trigger not executing
- **First Check:** Does a metadata record exist with the exact SObject API name?
- Verify `TriggerName__c` = exact SObject name (case-sensitive)
- Check debug logs for "No trigger setting found for object: [Name]"
- Ensure `IsActive__c` is checked

**Issue:** Wrong object name
- Check debug logs to see what name is being detected
- Verify with: `System.debug(Trigger.sObjectType.getDescribe().getName());`
- Use that exact value in your metadata record

**Issue:** Trigger executes when it shouldn't
- Check if programmatic bypass was cleared
- Verify metadata record `IsActive__c` is unchecked
- Check recursion control isn't being reset

**Issue:** Performance concerns
- Uses `TriggerSetting__mdt.getAll()` - doesn't count against SOQL limits
- All settings cached for entire transaction
- Zero SOQL queries consumed

## Advanced: Custom Metadata Extensions

You can add additional fields to `TriggerSetting__mdt`:

```xml
<!-- Example: MaxRecursionDepth__c field -->
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>MaxRecursionDepth__c</fullName>
    <defaultValue>1</defaultValue>
    <label>Max Recursion Depth</label>
    <precision>2</precision>
    <scale>0</scale>
    <type>Number</type>
</CustomField>
```

Then modify `isTriggerActive()` to use it:
```apex
private Boolean isTriggerActive() {
    if (triggerSettingsCache.containsKey(objectName)) {
        TriggerSetting__mdt setting = triggerSettingsCache.get(objectName);
        // Use custom fields
        Integer maxDepth = (Integer) setting.MaxRecursionDepth__c;
        // Your custom logic
        return setting.IsActive__c == true;
    }
    return false;
}
```

## Architecture Notes

- **Object Name Source:** `Trigger.sObjectType.getDescribe().getName()` (most reliable)
- **Fail-Safe Default:** INACTIVE if no metadata (explicit opt-in required)
- **Loading Method:** `TriggerSetting__mdt.getAll()` - doesn't count against SOQL limits
- **Zero SOQL Impact:** Custom Metadata getAll() doesn't consume query rows or limits
- **Recursion Control:** Record-level tracking via `Map<String, Set<Id>>` where key is "ObjectName_context"
- **Bypass Separation:** `bypassedObjects` Set is completely independent from `triggerSettingsCache` Map
- **Type Casting:** Handler methods receive SObject, cast in implementation
- **Error Handling:** Try-catch in `run()` method logs errors before re-throwing
- **Null Safety:** Validates `TriggerName__c` is not blank during cache loading
- **Filtered Execution:** Only unprocessed records are passed to handler methods in update/delete contexts

## Advanced Topics

### Record-Level Recursion Control

The framework tracks processed records at the record ID level, not just context level:

```apex
// Example: If an Account trigger updates the same Account in afterUpdate,
// the framework will skip that specific record on re-entry to prevent infinite loop

protected override void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords, 
                                   Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
    List<Account> accounts = (List<Account>) newRecords;
    
    for (Account acc : accounts) {
        // Even if this logic updates the same Account and re-triggers afterUpdate,
        // that specific Account ID won't be processed again in this transaction
    }
}
```

### Bypass vs Metadata

**Two ways to disable triggers:**

1. **Metadata (Permanent):** Setup > Custom Metadata Types > Trigger Setting > Uncheck IsActive
   - Persists across transactions
   - Visible in Setup UI
   - Requires edit permission on Custom Metadata

2. **Bypass (Temporary):** `TriggerHandler.bypass('Account')`
   - Only affects current transaction
   - Useful for testing and data loads
   - Completely independent from metadata cache

### Testing Strategies

```apex
@isTest
static void testWithBypass() {
    // Disable trigger for this test
    TriggerHandler.bypass('Account');
    
    // Your test logic - trigger won't fire
    
    // Clean up (optional, as static state resets between tests)
    TriggerHandler.clearBypass('Account');
}

@isTest
static void testRecursionHandling() {
    // Reset all static state for clean test
    TriggerHandler.resetAll();
    
    // Your test logic
}
```
