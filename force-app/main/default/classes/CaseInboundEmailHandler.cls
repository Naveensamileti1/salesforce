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
    public String messageId;

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

    // Flags
    public Boolean isDuplicateEmail = false;
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

      // Step 7 - Only process attachments if not a duplicate email
      if (!wrapper.isDuplicateEmail) {
        handleAttachments(wrapper);
      }

      result.success = true;
    } catch (Exception ex) {
      result.success = false;

      System.debug(
        LoggingLevel.ERROR,
        'Inbound Email Error: ' +
          ex.getMessage() +
          '\n' +
          ex.getStackTraceString()
      );
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

    // Safety: trim and truncate values
    String rawSubject = String.isNotBlank(email.subject)
      ? email.subject.trim()
      : 'No Subject';

    String rawPlain = String.isNotBlank(email.plainTextBody)
      ? email.plainTextBody.trim()
      : null;

    String rawHtml = String.isNotBlank(email.htmlBody)
      ? email.htmlBody.trim()
      : null;

    // Truncate subject to 255, bodies to 32000
    wrapper.subject = rawSubject != null ? rawSubject.left(255) : rawSubject;

    wrapper.plainTextBody = rawPlain != null ? rawPlain.left(32000) : null;

    wrapper.htmlBody = rawHtml != null ? rawHtml.left(32000) : null;

    // Convert headers list (if present) into a Map<String,String>
    wrapper.headers = new Map<String, String>();
    if (email != null && email.headers != null) {
      for (Messaging.InboundEmail.Header h : email.headers) {
        if (h != null && h.name != null) {
          wrapper.headers.put(h.name, h.value);

          // Capture Message-ID for duplicate detection
          if (h.name.equalsIgnoreCase('Message-ID')) {
            wrapper.messageId = h.value;
          }
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
    wrapper.caseId = EmailMessages.getRecordIdFromEmail(
      wrapper.subject,
      wrapper.plainTextBody,
      wrapper.htmlBody
    );

    // Validate the threaded Case still exists and cache the record
    if (wrapper.caseId != null) {
      List<Case> cases = [
        SELECT Id
        FROM Case
        WHERE Id = :wrapper.caseId
        LIMIT 1
      ];

      if (cases.isEmpty()) {
        wrapper.caseId = null;
      } else {
        wrapper.caseRecord = cases[0];
      }
    }
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

      String routingEmail = normalizeEmail(routing.Support_Queue_Email__c);

      Boolean matched = false;

      // Check TO Addresses
      for (String toEmail : wrapper.toAddresses) {
        if (toEmail != null && normalizeEmail(toEmail) == routingEmail) {
          matched = true;
          break;
        }
      }

      // Check CC Addresses
      if (!matched) {
        for (String ccEmail : wrapper.ccAddresses) {
          if (ccEmail != null && normalizeEmail(ccEmail) == routingEmail) {
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

    String senderEmail = normalizeEmail(wrapper.fromAddress);

    // Salesforce Email fields are case-insensitive by default
    List<Contact> contacts = [
      SELECT Id, AccountId
      FROM Contact
      WHERE Email = :senderEmail
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

    // Existing Case - use cached record, do not overwrite Description
    if (wrapper.caseRecord != null) {
      return wrapper.caseRecord;
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
    // Check for duplicate using Message-ID (globally, not per-Case)
    if (String.isNotBlank(wrapper.messageId)) {
      Integer existingCount = [
        SELECT COUNT()
        FROM EmailMessage
        WHERE MessageIdentifier = :wrapper.messageId
      ];

      if (existingCount > 0) {
        // Duplicate email, skip creation and flag to prevent duplicate attachments
        wrapper.isDuplicateEmail = true;
        return;
      }
    }

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

    // Note: MessageIdentifier may be read-only in some orgs/API versions
    // If deployment fails with "Field is not writeable: EmailMessage.MessageIdentifier",
    // remove this line. Duplicate check will still work if Salesforce auto-populates it.
    emailMessage.MessageIdentifier = wrapper.messageId;

    insert emailMessage;
  }

  // ===========================================================================
  // HANDLE ATTACHMENTS
  // ===========================================================================

  private void handleAttachments(EmailContextWrapper wrapper) {
    List<ContentVersion> versions = new List<ContentVersion>();

    Integer totalBytes = 0;
    final Integer MAX_TOTAL_ATTACHMENT_BYTES = 20 * 1024 * 1024; // Custom 20MB limit

    // -------------------------------------------------------------------------
    // Binary Attachments
    // -------------------------------------------------------------------------

    for (
      Messaging.InboundEmail.BinaryAttachment att : wrapper.binaryAttachments
    ) {
      if (att == null || att.body == null) {
        continue;
      }

      // Check attachment size limit
      Integer attSize = att.body.size();
      if (totalBytes + attSize > MAX_TOTAL_ATTACHMENT_BYTES) {
        System.debug(
          LoggingLevel.WARN,
          'Attachment size limit exceeded. Skipping remaining attachments.'
        );
        break;
      }

      totalBytes += attSize;

      ContentVersion cv = new ContentVersion();

      // Truncate filename to 255 characters
      String fileName = String.isNotBlank(att.fileName)
        ? att.fileName
        : 'BinaryAttachment';

      if (fileName.length() > 255) {
        fileName = fileName.left(255);
      }

      cv.Title = fileName;
      cv.PathOnClient = fileName;

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

      Blob textBlob = Blob.valueOf(att.body);

      // Check attachment size limit
      Integer attSize = textBlob.size();
      if (totalBytes + attSize > MAX_TOTAL_ATTACHMENT_BYTES) {
        System.debug(
          LoggingLevel.WARN,
          'Attachment size limit exceeded. Skipping remaining attachments.'
        );
        break;
      }

      totalBytes += attSize;

      ContentVersion cv = new ContentVersion();

      // Truncate filename to 255 characters
      String fileName = String.isNotBlank(att.fileName)
        ? att.fileName
        : 'TextAttachment';

      if (fileName.length() > 255) {
        fileName = fileName.left(255);
      }

      cv.Title = fileName;
      cv.PathOnClient = fileName;

      cv.VersionData = textBlob;

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

  // ===========================================================================
  // HELPER: NORMALIZE EMAIL
  // ===========================================================================

  /**
   * Normalizes an email address for case-insensitive comparison.
   * Handles formats like "Name <email@example.com>" and extracts the email.
   */
  private String normalizeEmail(String emailAddress) {
    if (String.isBlank(emailAddress)) {
      return null;
    }

    String normalized = emailAddress.trim().toLowerCase();

    // Extract email from "Name <email@example.com>" format
    if (normalized.contains('<') && normalized.contains('>')) {
      Integer startIndex = normalized.indexOf('<') + 1;
      Integer endIndex = normalized.indexOf('>');

      if (startIndex > 0 && endIndex > startIndex) {
        normalized = normalized.substring(startIndex, endIndex);
      }
    }

    return normalized;
  }
}
