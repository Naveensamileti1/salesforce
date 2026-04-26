public class SalesforcePracticeDay1 {
  public static void dataType() {
    Blob blobValue = Blob.valueOf('hello');
    Boolean booleanValue = true;
    Double doubleValue = 3.14;
    Decimal decimalValue = 8.99;

    Date dateToday = Date.today();
    Date datetendaysafter = Date.today().addDays(10);

    DateTime dateTimeToday2 = DateTime.now();
    DateTime dateTimeToday = System.now();

    Id idValue = '003dL000020rT1FQAU';

    Integer integerValue = 89;
    String stringValue = 'Naveen';
    Long longValue = 92342930482349L;

    Object o = 'sd';
    Object o2 = 123;

    Time timeValue = Time.newInstance(7, 4, 0, 0);

    // Debugs
    System.debug('Blob Value: ' + blobValue);
    System.debug('Boolean Value: ' + booleanValue);
    System.debug('Double Value: ' + doubleValue);
    System.debug('Decimal Value: ' + decimalValue);
    System.debug('Date Today: ' + dateToday);
    System.debug('Date +10 Days: ' + datetendaysafter);
    System.debug('DateTime.now(): ' + dateTimeToday2);
    System.debug('System.now(): ' + dateTimeToday);
    System.debug('Id Value: ' + idValue);
    System.debug('Integer Value: ' + integerValue);
    System.debug('String Value: ' + stringValue);
    System.debug('Long Value: ' + longValue);
    System.debug('Object o (String): ' + o);
    System.debug('Object o2 (Integer): ' + o2);
    System.debug('Time Value: ' + timeValue);
  }

  public static void accessModifier() {
    //public/private/global virtual/abstract with sharing/without sharing class ClassName extends className implements
    //Interface1,Interface2
    //public/private/global protected final/static variable Name
    //public/private/global protected override/static virtual

    String devName = 'Naveen';
  }

  public static void collections() {
    // List
    List<String> fruits = new List<String>{ 'Apple', 'Banana', 'Strawberry🍓' };

    fruits.add('Orange');
    fruits.add(0, 'Grapes 🍇'); // insert at index
    fruits.set(1, 'Kiwi'); // replace element

    // Debug important operations
    System.debug('Initial List: ' + fruits);

    System.debug('First Element: ' + fruits.get(0));
    System.debug('Is Empty: ' + fruits.isEmpty());
    System.debug('Contains Banana: ' + fruits.contains('Banana'));
    System.debug('Size: ' + fruits.size());

    // Clone
    List<String> fruits2 = fruits.clone();
    System.debug('Cloned List: ' + fruits2);

    // Compare
    System.debug('Lists Equal: ' + fruits.equals(fruits2));

    // Index
    System.debug('Index of Strawberry: ' + fruits.indexOf('Strawberry🍓'));

    // HashCode
    System.debug('HashCode: ' + fruits.hashCode());

    // Remove element
    fruits.remove(0);
    System.debug('After Remove: ' + fruits);

    // Clear list (keep at end)
    fruits.clear();
    System.debug('After Clear: ' + fruits);

    // Set (no duplicates, unordered)
    Set<String> fruitSet = new Set<String>{ 'Apple', 'Banana', 'Strawberry🍓' };

    fruitSet.add('Orange');
    fruitSet.add('Apple'); // duplicate (will NOT be added)

    System.debug('Initial Set: ' + fruitSet);

    System.debug('Is Empty: ' + fruitSet.isEmpty());
    System.debug('Contains Banana: ' + fruitSet.contains('Banana'));
    System.debug('Size (no duplicates): ' + fruitSet.size());

    // Clone
    Set<String> fruitSetClone = fruitSet.clone();
    System.debug('Cloned Set: ' + fruitSetClone);

    // Compare
    System.debug('Sets Equal: ' + fruitSet.equals(fruitSetClone));

    // HashCode
    System.debug('HashCode: ' + fruitSet.hashCode());

    // Remove element
    fruitSet.remove('Banana');
    System.debug('After Remove Banana: ' + fruitSet);

    // Clear set (keep at end)
    fruitSet.clear();
    System.debug('After Clear: ' + fruitSet);

    // Map (Key → Value)
    Map<Integer, String> fruitBasket = new Map<Integer, String>{
      1 => 'Apple',
      2 => 'Banana'
    };

    fruitBasket.put(4, 'Grapes');
    System.debug('Initial Map: ' + fruitBasket);

    // Remove
    fruitBasket.remove(1);
    System.debug('After Remove Key 1: ' + fruitBasket);

    // Access
    System.debug('Get Key 2: ' + fruitBasket.get(2));

    // Keys & Values
    System.debug('Keys: ' + fruitBasket.keySet());
    System.debug('Values: ' + fruitBasket.values());

    // Checks
    System.debug('Is Empty: ' + fruitBasket.isEmpty());
    System.debug('Contains Key 4: ' + fruitBasket.containsKey(4));
    System.debug('Size: ' + fruitBasket.size());

    // Clone (valid)
    Map<Integer, String> fruitBasket2 = fruitBasket.clone();
    System.debug('Cloned Map: ' + fruitBasket2);

    // Compare
    Boolean isEqual = fruitBasket.equals(fruitBasket2);
    System.debug('Maps Equal: ' + isEqual);

    // HashCode & String
    System.debug('HashCode: ' + fruitBasket.hashCode());
    System.debug('ToString: ' + fruitBasket.toString());

    // Clear
    fruitBasket.clear();
    System.debug('After Clear: ' + fruitBasket);
    Map<Id, Account> acc = new Map<Id, Account>(
      [SELECT Id, Name FROM Account LIMIT 2]
    );

    System.debug('Account Map: ' + acc);

    // Step 1: Get Accounts
    List<Account> accList = [SELECT Id, Name FROM Account LIMIT 2];

    // Step 2: Initialize Map
    Map<Id, List<Contact>> accToContacts = new Map<Id, List<Contact>>();

    // Step 3: Query Contacts related to those Accounts
    List<Contact> conList = [
      SELECT Id, Name, AccountId
      FROM Contact
      WHERE AccountId IN :accList
    ];

    // Step 4: Group Contacts by AccountId
    for (Contact con : conList) {
      if (!accToContacts.containsKey(con.AccountId)) {
        accToContacts.put(con.AccountId, new List<Contact>());
      }

      accToContacts.get(con.AccountId).add(con);
    }

    // Debug
    System.debug('Account → Contacts Map: ' + accToContacts);
  }
}
