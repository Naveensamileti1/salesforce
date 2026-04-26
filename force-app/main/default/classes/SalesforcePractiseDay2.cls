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
    System.debug('endsWith: ' + str.endsWith('! ')); // false
    System.debug('indexOf: ' + str.indexOf('Salesforce')); // 8
    System.debug('lastIndexOf: ' + str.lastIndexOf('e')); // last e index

    // ===============================
    // 2. CASE & FORMAT
    // ===============================
    System.debug('toUpperCase: ' + str.toUpperCase()); // " HELLO, SALESFORCE! "
    System.debug('toLowerCase: ' + str.toLowerCase()); // " hello, salesforce! "
    System.debug('capitalize: ' + str.trim().capitalize()); // "Hello, Salesforce!"
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
    // System.debug('abbreviate: ' + String.abbreviate(str, 10)); // " Hello, ..." // Method doesn't exist in Apex

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
    System.debug('repeat: ' + str.repeat(2)); // repeated string

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
}
