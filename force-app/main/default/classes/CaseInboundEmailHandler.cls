/**
 * -----------------------------------------------------------------------------
 * CaseInboundEmailHandler
 * -----------------------------------------------------------------------------
 * Handles:
 * - New Case creation
 * - Existing Case threading
 * - Queue routing using Custom Metadata
 * - Contact/Account matching
 * - EmailMessage creation
 * - Binary attachment handling
 * - Text attachment handling
 * - ContentDocumentLink creation
 * -----------------------------------------------------------------------------
 */
global with sharing class CaseInboundEmailHandler implements Messaging.InboundEmailHandler {
  // ===========================================================================
  // WRAPPER
  // ===========================================================================

  public class EmailContextWrapper {
    // Email Details
    public String fromAddress;
    public List<String> toAddresses;
    public List<String> ccAddresses;
    // bccAddresses not used in Apex (removed)
    // public List<String> bccAddresses;

    public String subject;
    public String plainTextBody;
    public String htmlBody;

    public Map<String, String> headers;

    // Salesforce Data
    public Id caseId;
    public Id contactId;
    public Id accountId;
    public Id ownerId;

    // Attachments
    public List<Messaging.InboundEmail.BinaryAttachment> binaryAttachments;

    public List<Messaging.InboundEmail.TextAttachment> textAttachments;

    // Runtime Object
    public Case caseRecord;
  }

  // ===========================================================================
  // MAIN ENTRY
  // ===========================================================================

  global Messaging.InboundEmailResult handleInboundEmail(
    Messaging.InboundEmail email,
    Messaging.InboundEnvelope envelope
  ) {
    Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

    try {
      // Step 1
      EmailContextWrapper wrapper = extractEmailDetails(email, envelope);

      // Step 2
      extractExistingCase(wrapper);

      // Step 3
      assignQueue(wrapper);

      // Step 4
      extractContactAndAccount(wrapper);

      // Step 5
      Case caseRecord = createOrUpdateCase(wrapper);

      wrapper.caseId = caseRecord.Id;

      // Step 6
      createEmailMessage(wrapper);

      // Step 7
      handleAttachments(wrapper);

      result.success = true;
    } catch (Exception ex) {
      result.success = false;

      System.debug('Inbound Email Error: ' + ex.getMessage());
    }

    return result;
  }

  // ===========================================================================
  // EXTRACT EMAIL DETAILS
  // ===========================================================================

  private EmailContextWrapper extractEmailDetails(
    Messaging.InboundEmail email,
    Messaging.InboundEnvelope envelope
  ) {
    EmailContextWrapper wrapper = new EmailContextWrapper();

    wrapper.fromAddress = email.fromAddress;

    wrapper.toAddresses = email.toAddresses != null
      ? email.toAddresses
      : new List<String>();

    wrapper.ccAddresses = email.ccAddresses != null
      ? email.ccAddresses
      : new List<String>();

    // bccAddresses omitted (not supported for EmailMessage in this org)

        // Safety: trim, truncate to 255 chars and escape single quotes.
    String rawSubject = String.isNotBlank(email.subject)
      ? email.subject.trim()
      : 'No Subject';

    String rawPlain = String.isNotBlank(email.plainTextBody)
      ? email.plainTextBody.trim()
      : null;

    String rawHtml = String.isNotBlank(email.htmlBody)
      ? email.htmlBody.trim()
      : null;

    // Truncate to 255 and escape single quotes
    wrapper.subject = rawSubject != null ? truncate(rawSubject, 255) : rawSubject;
    if (wrapper.subject != null) wrapper.subject = String.escapeSingleQuotes(wrapper.subject);

    wrapper.plainTextBody = rawPlain != null ? truncate(rawPlain, 255) : null;
    if (wrapper.plainTextBody != null) wrapper.plainTextBody = String.escapeSingleQuotes(wrapper.plainTextBody);

    wrapper.htmlBody = rawHtml != null ? truncate(rawHtml, 255) : null;
    if (wrapper.htmlBody != null) wrapper.htmlBody = String.escapeSingleQuotes(wrapper.htmlBody);

    // Convert headers list (if present) into a Map<String,String>
    wrapper.headers = new Map<String, String>();
    if (email != null && email.headers != null) {
      for (Messaging.InboundEmail.Header h : email.headers) {
        if (h != null && h.name != null) {
          wrapper.headers.put(h.name, h.value);
        }
      }
    }

    wrapper.binaryAttachments = email.binaryAttachments != null
      ? email.binaryAttachments
      : new List<Messaging.InboundEmail.BinaryAttachment>();

    wrapper.textAttachments = email.textAttachments != null
      ? email.textAttachments
      : new List<Messaging.InboundEmail.TextAttachment>();

    return wrapper;
  }

  // ===========================================================================
  // FIND EXISTING CASE
  // ===========================================================================

  private void extractExistingCase(EmailContextWrapper wrapper) {
    // Use the cross-org-safe helper only.
    wrapper.caseId =
      EmailMessages.getRecordIdFromEmail(
        wrapper.subject,
        wrapper.plainTextBody,
        wrapper.htmlBody
      );
  }

  // ===========================================================================
  // ASSIGN QUEUE
  // ===========================================================================

  private void assignQueue(EmailContextWrapper wrapper) {
    Map<String, Email_Message_Queue_Routing__mdt> routingMap = Email_Message_Queue_Routing__mdt.getAll();

    Set<String> queueNames = new Set<String>();

    for (Email_Message_Queue_Routing__mdt routing : routingMap.values()) {
      if (String.isNotBlank(routing.Queue_Name__c)) {
        queueNames.add(routing.Queue_Name__c);
      }
    }

    Map<String, Group> queueByName = new Map<String, Group>();

    if (!queueNames.isEmpty()) {
      for (Group grp : [
        SELECT Id, Name
        FROM Group
        WHERE Name IN :queueNames AND Type = 'Queue'
      ]) {
        queueByName.put(grp.Name, grp);
      }
    }

    for (Email_Message_Queue_Routing__mdt routing : routingMap.values()) {
      if (String.isBlank(routing.Support_Queue_Email__c)) {
        continue;
      }

      String routingEmail = routing.Support_Queue_Email__c.toLowerCase();

      Boolean matched = false;

      // Check TO Addresses
      for (String toEmail : wrapper.toAddresses) {
        if (toEmail != null && toEmail.toLowerCase() == routingEmail) {
          matched = true;
          break;
        }
      }

      // Check CC Addresses
      if (!matched) {
        for (String ccEmail : wrapper.ccAddresses) {
          if (ccEmail != null && ccEmail.toLowerCase() == routingEmail) {
            matched = true;
            break;
          }
        }
      }

      if (matched && queueByName.containsKey(routing.Queue_Name__c)) {
        wrapper.ownerId = queueByName.get(routing.Queue_Name__c).Id;

        break;
      }
    }
  }

  // ===========================================================================
  // CONTACT + ACCOUNT MATCHING
  // ===========================================================================

  private void extractContactAndAccount(EmailContextWrapper wrapper) {
    if (String.isBlank(wrapper.fromAddress)) {
      return;
    }

    List<Contact> contacts = [
      SELECT Id, AccountId, Email
      FROM Contact
      WHERE Email = :wrapper.fromAddress
      LIMIT 1
    ];

    if (!contacts.isEmpty()) {
      Contact con = contacts[0];

      wrapper.contactId = con.Id;

      wrapper.accountId = con.AccountId;
    }
  }

  // ===========================================================================
  // CREATE OR UPDATE CASE
  // ===========================================================================

  private Case createOrUpdateCase(EmailContextWrapper wrapper) {
    Case caseRecord;

    // Existing Case
    if (wrapper.caseId != null) {
      caseRecord = new Case(Id = wrapper.caseId);

      caseRecord.Description = wrapper.plainTextBody;

      update caseRecord;
    }
    // New Case
    else {
      caseRecord = new Case();

      caseRecord.Subject = wrapper.subject;

      caseRecord.Description = wrapper.plainTextBody;

      caseRecord.ContactId = wrapper.contactId;

      caseRecord.AccountId = wrapper.accountId;

      if (wrapper.ownerId != null) {
        caseRecord.OwnerId = wrapper.ownerId;
      }

      caseRecord.Origin = 'Email';

      insert caseRecord;
    }

    wrapper.caseRecord = caseRecord;

    return caseRecord;
  }

  // ===========================================================================
  // CREATE EMAIL MESSAGE
  // ===========================================================================

  private void createEmailMessage(EmailContextWrapper wrapper) {
    EmailMessage emailMessage = new EmailMessage();

    emailMessage.ParentId = wrapper.caseId;

    emailMessage.Incoming = true;

    emailMessage.Status = '3';

    emailMessage.FromAddress = wrapper.fromAddress;

    emailMessage.ToAddress = wrapper.toAddresses != null
      ? String.join(wrapper.toAddresses, ';')
      : null;

    emailMessage.CcAddress = wrapper.ccAddresses != null
      ? String.join(wrapper.ccAddresses, ';')
      : null;

    // BccAddress omitted: platform EmailMessage.BccAddress not supported in this org

    emailMessage.Subject = wrapper.subject;

    emailMessage.TextBody = wrapper.plainTextBody;

    emailMessage.HtmlBody = wrapper.htmlBody;

    insert emailMessage;
  }

  // ===========================================================================
  // HANDLE ATTACHMENTS
  // ===========================================================================

  private void handleAttachments(EmailContextWrapper wrapper) {
    List<ContentVersion> versions = new List<ContentVersion>();

    // -------------------------------------------------------------------------
    // Binary Attachments
    // -------------------------------------------------------------------------

    for (
      Messaging.InboundEmail.BinaryAttachment att : wrapper.binaryAttachments
    ) {
      if (att == null || att.body == null) {
        continue;
      }

      ContentVersion cv = new ContentVersion();

      cv.Title = String.isNotBlank(att.fileName)
        ? att.fileName
        : 'BinaryAttachment';

      cv.PathOnClient = String.isNotBlank(att.fileName)
        ? att.fileName
        : 'BinaryAttachment';

      cv.VersionData = att.body;

      versions.add(cv);
    }

    // -------------------------------------------------------------------------
    // Text Attachments
    // -------------------------------------------------------------------------

    for (Messaging.InboundEmail.TextAttachment att : wrapper.textAttachments) {
      if (att == null || String.isBlank(att.body)) {
        continue;
      }

      ContentVersion cv = new ContentVersion();

      cv.Title = String.isNotBlank(att.fileName)
        ? att.fileName
        : 'TextAttachment';

      cv.PathOnClient = String.isNotBlank(att.fileName)
        ? att.fileName
        : 'TextAttachment';

      cv.VersionData = Blob.valueOf(att.body);

      versions.add(cv);
    }

    if (versions.isEmpty()) {
      return;
    }

    insert versions;

    // -------------------------------------------------------------------------
    // Query ContentDocumentId
    // -------------------------------------------------------------------------

    List<ContentVersion> insertedVersions = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id IN :versions
    ];

    List<ContentDocumentLink> links = new List<ContentDocumentLink>();

    for (ContentVersion cv : insertedVersions) {
      links.add(
        new ContentDocumentLink(
          LinkedEntityId = wrapper.caseId,
          ContentDocumentId = cv.ContentDocumentId,
          ShareType = 'V',
          Visibility = 'AllUsers'
        )
      );
    }

        if (!links.isEmpty()) {
            insert links;
        }
    }

  // Helper: safe truncation
  private static String truncate(String s, Integer len) {
    if (s == null) return null;
    if (s.length() <= len) return s;
    return s.substring(0, len);
  }
}