public with sharing class SalesforcePractiseDay2 {
  public static void stringMethods() {
    String str = ' Hello, Salesforce! ';
    String str2 = 'hello, salesforce!';
    String alpha = 'ABC123';

    // ===============================
    // 1. BASIC & SEARCH
    // ===============================
    System.debug('length: ' + str.length()); // 21
    System.debug('contains: ' + str.contains('Salesforce')); // true
    System.debug('startsWith: ' + str.startsWith(' ')); // true
    System.debug('endsWith: ' + str.endsWith('! ')); // true
    System.debug('indexOf: ' + str.indexOf('Salesforce')); // 8
    System.debug('lastIndexOf: ' + str.lastIndexOf('e')); // last e index

    // ===============================
    // 2. CASE & FORMAT
    // ===============================
    System.debug('toUpperCase: ' + str.toUpperCase()); // " HELLO, SALESFORCE! "
    System.debug('toLowerCase: ' + str.toLowerCase()); // " hello, salesforce! "
    System.debug('capitalize: ' + str2.trim().capitalize()); // "Hello, Salesforce!"
    System.debug('swapCase: ' + str.swapCase()); // " hELLO, sALESFORCE! "

    // ===============================
    // 3. TRIM / CLEANING
    // ===============================
    System.debug('trim: ' + str.trim()); // "Hello, Salesforce!"
    System.debug('normalizeSpace: ' + str.normalizeSpace()); // "Hello, Salesforce!"
    System.debug('deleteWhitespace: ' + str.deleteWhitespace()); // "Hello,Salesforce!"

    // ===============================
    // 4. SUBSTRING / EXTRACTION
    // ===============================
    System.debug('substring: ' + str.substring(1, 6)); // "Hello"
    System.debug('substringAfter: ' + str.substringAfter(', ')); // "Salesforce! "
    System.debug('substringBefore: ' + str.substringBefore(',')); // " Hello"
    System.debug('mid: ' + str.mid(1, 5)); // "Hello"

    // ===============================
    // 5. LENGTH CONTROL (🔥 IMPORTANT)
    // ===============================
    System.debug('left(5): ' + str.left(5)); // " Hell"
    System.debug('right(5): ' + str.right(5)); // "ce! "
    System.debug('abbreviate: ' + str.abbreviate(10)); // " Hello, ..."

    // SAFE truncate
    Integer maxLength = 10;
    String safe = str.length() > maxLength ? str.substring(0, maxLength) : str;
    System.debug('safe truncate: ' + safe); // first 10 chars

    // ===============================
    // 6. REPLACE / MODIFY
    // ===============================
    System.debug('replace: ' + str.replace('Salesforce', 'World')); // " Hello, World! "
    System.debug('remove: ' + str.remove('Salesforce')); // " Hello, ! "
    System.debug('removeStart: ' + str.removeStart(' ')); // "Hello, Salesforce! "
    System.debug('removeEnd: ' + str.removeEnd(' ')); // " Hello, Salesforce!"
    System.debug('repeat: ' + str.repeat(2)); // repeated string  Hello, Salesforce!  Hello, Salesforce!

    // ===============================
    // 7. SPLIT / JOIN
    // ===============================
    List<String> parts = str.split(', ');
    System.debug('split: ' + parts); // (" Hello", "Salesforce! ")

    System.debug('join: ' + String.join(parts, '-')); // " Hello-Salesforce! "

    // ===============================
    // 8. COMPARISON
    // ===============================
    System.debug('equals: ' + str.equals(str)); // true
    System.debug('equalsIgnoreCase: ' + str.equalsIgnoreCase(str2)); // true
    System.debug('compareTo: ' + str.compareTo(str2)); // >0 or <0
    System.debug('containsIgnoreCase: ' + str.containsIgnoreCase('salesforce')); // true

    // ===============================
    // 9. VALIDATION / SAFETY (🔥 VERY IMPORTANT)
    // ===============================
    System.debug('isBlank: ' + String.isBlank('   ')); // true
    System.debug('isEmpty: ' + String.isEmpty('')); // true
    System.debug('isAlpha: ' + 'ABC'.isAlpha()); // true
    System.debug('isAlphanumeric: ' + alpha.isAlphanumeric()); // true
    System.debug('isNumeric: ' + '123'.isNumeric()); // true

    // ===============================
    // 10. ESCAPE / SECURITY (🔥 IMPORTANT)
    // ===============================
    System.debug(
      'escapeSingleQuotes: ' + String.escapeSingleQuotes('It\'s good')
    ); // It\'s good
    // System.debug('escapeHtml4: ' + String.escapeHtml4('<b>Hi</b>')); // <b>Hi</b> // Method doesn't exist in Apex

    // ===============================
    // 11. ADVANCED / INTERVIEW
    // ===============================
    System.debug('countMatches: ' + str.countMatches('l')); // count of 'l'
    System.debug('reverse: ' + str.reverse()); // reversed string
    System.debug('difference: ' + str.difference(str2)); // diff part
    System.debug('Levenshtein: ' + str.getLevenshteinDistance(str2)); // distance

    // ===============================
    // 12. PADDING / UI
    // ===============================
    System.debug('leftPad: ' + str.leftPad(25, '*')); // padded left
    System.debug('rightPad: ' + str.rightPad(25, '*')); // padded right
    System.debug('center: ' + str.center(25, '*')); // centered

    // ===============================
    // 13. CONVERSION
    // ===============================
    System.debug('valueOf int: ' + String.valueOf(123)); // "123"
    System.debug('valueOf date: ' + String.valueOf(Date.today())); // yyyy-MM-dd

    // ===============================
    // 14. HTML / TEXT CLEAN
    // ===============================
    System.debug('stripHtmlTags: ' + '<b>Hello</b>'.stripHtmlTags()); // "Hello"
  }

  public static void emailMsgValidation() {
    String emailMsg =
      '    HELLO Team,\n\n' +
      'My order SR-A123 is delayed!!!\n\n' +
      'Please help ASAP It is Urgent.\n\n' +
      'Thanks,\n' +
      'Naveen';

    // =====================================================
    // STEP 1 : VALIDATE EMAIL
    // =====================================================

    if (!String.isBlank(emailMsg)) {
      System.debug('Email received successfully');
      // OUTPUT: Email received successfully
    }

    // =====================================================
    // STEP 2 : CLEAN EXTRA SPACES
    // =====================================================

    emailMsg = emailMsg.trim();

    System.debug('trim(): ' + emailMsg);
    // OUTPUT CHANGED:
    // Removed starting spaces before HELLO

    // =====================================================
    // STEP 3 : NORMALIZE SPACES
    // =====================================================

    emailMsg = emailMsg.normalizeSpace();

    System.debug('normalizeSpace(): ' + emailMsg);
    // OUTPUT CHANGED:
    // Multiple spaces/newlines cleaned into proper spacing

    // =====================================================
    // STEP 4 : CHECK URGENT EMAIL
    // =====================================================

    Boolean isUrgent = emailMsg.containsIgnoreCase('urgent');

    System.debug('containsIgnoreCase(): ' + isUrgent);
    // OUTPUT: true

    // =====================================================
    // STEP 5 : CHECK ASAP KEYWORD
    // =====================================================

    Boolean hasAsap = emailMsg.contains('ASAP');

    System.debug('contains(): ' + hasAsap);
    // OUTPUT: true

    // =====================================================
    // STEP 6 : EXTRACT SERVICE REQUEST NUMBER
    // =====================================================

    String srNumber = emailMsg.substringAfter('SR-');

    srNumber = srNumber.substringBefore(' ');

    System.debug('SR Number: ' + srNumber);
    // OUTPUT: A123

    // =====================================================
    // STEP 7 : COUNT EXCLAMATIONS (SPAM CHECK)
    // =====================================================

    Integer exclamations = emailMsg.countMatches('!');

    System.debug('countMatches(): ' + exclamations);
    // OUTPUT: 3

    // =====================================================
    // STEP 8 : REPLACE ASAP WORD
    // =====================================================

    emailMsg = emailMsg.replace('ASAP', 'Immediately');

    System.debug('replace(): ' + emailMsg);
    // OUTPUT CHANGED:
    // ASAP → Immediately

    // =====================================================
    // STEP 9 : REMOVE WORD
    // =====================================================

    emailMsg = emailMsg.remove('Urgent');

    System.debug('remove(): ' + emailMsg);
    // OUTPUT CHANGED:
    // Urgent removed

    // =====================================================
    // STEP 10 : CONVERT FOR SEARCH ENGINE
    // =====================================================

    String searchText = emailMsg.toLowerCase();

    System.debug('toLowerCase(): ' + searchText);
    // OUTPUT CHANGED:
    // Entire email converted to lowercase

    // =====================================================
    // STEP 11 : CREATE SHORT EMAIL PREVIEW
    // =====================================================

    String preview = emailMsg.abbreviate(40);

    System.debug('abbreviate(): ' + preview);
    // OUTPUT CHANGED:
    // HELLO Team, My order SR-A123 is...

    // =====================================================
    // STEP 12 : SPLIT INTO WORDS
    // =====================================================

    List<String> words = emailMsg.split(' ');

    System.debug('split(): ' + words);
    // OUTPUT CHANGED:
    // Email converted into word list

    // =====================================================
    // STEP 13 : GENERATE PIPE REPORT
    // =====================================================

    String report = String.join(words, '|');

    System.debug('join(): ' + report);
    // OUTPUT CHANGED:
    // HELLO|Team,|My|order...

    // =====================================================
    // STEP 14 : CHECK EMAIL LENGTH
    // =====================================================

    System.debug('length(): ' + emailMsg.length());
    // OUTPUT:
    // Total characters count

    // =====================================================
    // STEP 15 : GET FIRST 20 CHARACTERS
    // =====================================================

    System.debug('left(): ' + emailMsg.left(20));
    // OUTPUT:
    // HELLO Team, My orde

    // =====================================================
    // STEP 16 : GET LAST 20 CHARACTERS
    // =====================================================

    System.debug('right(): ' + emailMsg.right(20));
    // OUTPUT:
    // Thanks, Naveen

    // =====================================================
    // STEP 17 : SECURE USER INPUT
    // =====================================================

    String customerInput = 'Naveen\'s urgent ticket';

    String safeInput = String.escapeSingleQuotes(customerInput);

    System.debug('escapeSingleQuotes(): ' + safeInput);
    // OUTPUT CHANGED:
    // Naveen\'s urgent ticket

    // =====================================================
    // STEP 18 : REMOVE HTML TAGS
    // =====================================================

    String htmlMsg = '<b>Payment Failed</b>';

    System.debug('stripHtmlTags(): ' + htmlMsg.stripHtmlTags());
    // OUTPUT:
    // Payment Failed

    // =====================================================
    // STEP 19 : REVERSE STRING
    // =====================================================

    System.debug('reverse(): ' + emailMsg.reverse());
    // OUTPUT CHANGED:
    // Entire text reversed

    // =====================================================
    // STEP 20 : FINAL EMAIL READY
    // =====================================================

    System.debug('Final Processed Email:\n' + emailMsg);
  }
}
