public with sharing class EmailUtility {
  private static final Pattern EMAIL_PATTERN = Pattern.compile(
    '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
  );
  /**********************************************************************
   * PUBLIC METHODS
   **********************************************************************/

  public static List<EmailResult> sendEmail(EmailRequest request) {
    return sendEmail(new List<EmailRequest>{ request });
  }

  public static List<EmailResult> sendEmail(List<EmailRequest> requests) {
    List<EmailResult> results = new List<EmailResult>();

    if (requests == null || requests.isEmpty()) {
      return results;
    }

    // Validate all requests
    validateRequests(requests);

    // Enrich requests (templates, recipients, attachments)
    enrichRequests(requests);

    // Build email messages
    List<Messaging.SingleEmailMessage> emails = buildEmails(requests);

    // Messaging.sendEmail accepts one allOrNothing flag for the batch.
    Boolean allOrNothing = requests[0].allOrNothing;

    // Ensure all requests use the same setting.
    for (EmailRequest req : requests) {
      if (req.allOrNothing != allOrNothing) {
        throw new EmailFrameworkException(
          'All EmailRequests in the same batch must use the same allOrNothing value.'
        );
      }
    }

    System.debug('Emails to send: ' + emails.size());
    System.debug('Email object: ' + emails);

    // Send emails
    List<Messaging.SendEmailResult> sendResults = Messaging.sendEmail(
      emails,
      allOrNothing
    );

    Integer index = 0;

    for (Messaging.SendEmailResult sendResult : sendResults) {
      EmailResult result = new EmailResult();

      result.success = sendResult.isSuccess();

      if (!sendResult.isSuccess()) {
        List<String> errors = new List<String>();

        for (Messaging.SendEmailError error : sendResult.getErrors()) {
          errors.add(error.getMessage());
        }

        result.errorMessage = String.join(errors, '; ');
      }

      result.salesforceResult = sendResult;
      result.request = requests[index];

      results.add(result);

      index++;
    }

    for (Messaging.SendEmailResult r : sendResults) {
      System.debug('Success: ' + r.isSuccess());

      if (!r.isSuccess()) {
        for (Messaging.SendEmailError e : r.getErrors()) {
          System.debug(e.getMessage());
        }
      }
    }

    return results;
  }

  /**********************************************************************
   * VALIDATE REQUESTS
   **********************************************************************/
  private static void validateRequests(List<EmailRequest> requests) {
    Integer requestNumber = 1;

    for (EmailRequest req : requests) {
      if (req == null) {
        throw new EmailFrameworkException(
          'EmailRequest #' + requestNumber + ' cannot be null.'
        );
      }

      // -------------------------------------------------------
      // Validate Template / Body
      // -------------------------------------------------------

      Boolean hasTemplate =
        req.templateId != null || !String.isBlank(req.templateDeveloperName);

      Boolean hasContent =
        !String.isBlank(req.subject) ||
        !String.isBlank(req.body) ||
        !String.isBlank(req.htmlBody);

      if (!hasTemplate && !hasContent) {
        throw new EmailFrameworkException(
          'EmailRequest #' +
            requestNumber +
            ' must have either an Email Template or email content.'
        );
      }

      if (hasTemplate && hasContent) {
        throw new EmailFrameworkException(
          'Cannot specify both Email Template and Subject/Body.'
        );
      }

      // Direct template sending requires targetObjectId.
      // Rendered templates can later be sent using ToAddresses.
      if (hasTemplate && !req.renderTemplate && req.targetObjectId == null) {
        throw new EmailFrameworkException(
          'EmailRequest #' +
            requestNumber +
            ' requires targetObjectId when sending an Email Template directly.'
        );
      }

      // -------------------------------------------------------
      // Validate Recipients
      // -------------------------------------------------------

      Boolean hasRecipients =
        req.targetObjectId != null ||
        !req.toAddresses.isEmpty() ||
        !req.userIds.isEmpty() ||
        !req.queueIds.isEmpty();

      if (!hasRecipients) {
        throw new EmailFrameworkException(
          'EmailRequest #' + requestNumber + ' has no recipients.'
        );
      }

      requestNumber++;
    }
  }

  /**********************************************************************
   * ENRICH REQUESTS
   *
   * Resolves framework-managed data before building emails.
   **********************************************************************/
  private static void enrichRequests(List<EmailRequest> requests) {
    if (requests == null || requests.isEmpty()) {
      return;
    }

    // Resolve Template DeveloperName -> Template Id
    resolveTemplateIds(requests);

    // Resolve manually supplied email addresses
    resolveDirectAddresses(requests);

    // Resolve User email addresses
    resolveUsers(requests);

    // Resolve Queue members
    resolveQueueMembers(requests);

    // Resolve ContentVersion attachments
    resolveAttachments(requests);

    // Remove duplicate email addresses
    for (EmailRequest request : requests) {
      request.resolvedToAddresses = removeDuplicates(
        new List<String>(request.resolvedToAddresses)
      );

      request.resolvedCcAddresses = removeDuplicates(
        new List<String>(request.resolvedCcAddresses)
      );

      request.resolvedBccAddresses = removeDuplicates(
        new List<String>(request.resolvedBccAddresses)
      );
    }
  }

  /**********************************************************************
   * RESOLVE TEMPLATE IDS
   *
   * Populates templateId from templateDeveloperName.
   **********************************************************************/
  private static void resolveTemplateIds(List<EmailRequest> requests) {
    Set<String> developerNames = new Set<String>();

    // Collect all unique template developer names
    for (EmailRequest request : requests) {
      if (
        request.templateId == null &&
        !String.isBlank(request.templateDeveloperName)
      ) {
        developerNames.add(request.templateDeveloperName.trim());
      }
    }

    if (developerNames.isEmpty()) {
      return;
    }

    // Query all templates in a single SOQL
    Map<String, Id> templateMap = new Map<String, Id>();

    for (EmailTemplate template : [
      SELECT Id, DeveloperName
      FROM EmailTemplate
      WHERE DeveloperName IN :developerNames
    ]) {
      templateMap.put(template.DeveloperName, template.Id);
    }

    // Populate each request
    for (EmailRequest request : requests) {
      if (request.templateId != null) {
        continue;
      }

      if (String.isBlank(request.templateDeveloperName)) {
        continue;
      }

      String developerName = request.templateDeveloperName.trim();

      Id templateId = templateMap.get(developerName);

      if (templateId == null) {
        throw new EmailFrameworkException(
          'Email Template not found: ' + request.templateDeveloperName
        );
      }

      request.templateId = templateId;
    }
  }

  /**********************************************************************
   * RESOLVE USER EMAIL ADDRESSES
   *
   * Converts User Ids into email addresses.
   **********************************************************************/
  private static void resolveUsers(List<EmailRequest> requests) {
    Set<Id> userIds = new Set<Id>();

    // Collect all unique User Ids
    for (EmailRequest request : requests) {
      userIds.addAll(request.userIds);
    }

    if (userIds.isEmpty()) {
      return;
    }

    // Query active users once
    Map<Id, User> userMap = new Map<Id, User>(
      [
        SELECT Id, Email, IsActive
        FROM User
        WHERE Id IN :userIds
      ]
    );

    // Populate resolved email addresses
    for (EmailRequest request : requests) {
      for (Id userId : request.userIds) {
        User user = userMap.get(userId);

        if (user == null) {
          continue;
        }

        if (!user.IsActive) {
          continue;
        }

        if (String.isBlank(user.Email)) {
          continue;
        }

        request.resolvedToAddresses.add(user.Email.trim());
      }
    }
  }

  /**********************************************************************
   * RESOLVE DIRECT EMAIL ADDRESSES
   *
   * Copies manually supplied To/CC/BCC addresses into the resolved lists.
   **********************************************************************/
  private static void resolveDirectAddresses(List<EmailRequest> requests) {
    for (EmailRequest request : requests) {
      request.resolvedToAddresses.addAll(request.toAddresses);

      request.resolvedCcAddresses.addAll(request.ccAddresses);

      request.resolvedBccAddresses.addAll(request.bccAddresses);
    }
  }

  /**********************************************************************
   * RESOLVE QUEUE MEMBERS
   *
   * Resolves Queue members into active User email addresses.
   **********************************************************************/
  private static void resolveQueueMembers(List<EmailRequest> requests) {
    Set<Id> queueIds = new Set<Id>();

    // Collect Queue Ids
    for (EmailRequest request : requests) {
      if (request.includeQueueMembers) {
        queueIds.addAll(request.queueIds);
      }
    }

    if (queueIds.isEmpty()) {
      return;
    }

    // Queue -> UserIds
    Map<Id, Set<Id>> queueUserMap = new Map<Id, Set<Id>>();

    Set<Id> userIds = new Set<Id>();

    for (GroupMember gm : [
      SELECT GroupId, UserOrGroupId
      FROM GroupMember
      WHERE GroupId IN :queueIds
    ]) {
      // Only Users
      if (isUser(gm.UserOrGroupId)) {
        if (!queueUserMap.containsKey(gm.GroupId)) {
          queueUserMap.put(gm.GroupId, new Set<Id>());
        }

        queueUserMap.get(gm.GroupId).add(gm.UserOrGroupId);

        userIds.add(gm.UserOrGroupId);
      }
    }

    if (userIds.isEmpty()) {
      return;
    }

    // Query Active Users

    Map<Id, User> users = new Map<Id, User>(
      [
        SELECT Id, Email, IsActive
        FROM User
        WHERE Id IN :userIds
      ]
    );

    // Populate Requests

    for (EmailRequest request : requests) {
      for (Id queueId : request.queueIds) {
        Set<Id> members = queueUserMap.get(queueId);

        if (members == null) {
          continue;
        }

        for (Id userId : members) {
          User u = users.get(userId);

          if (u == null) {
            continue;
          }

          if (!u.IsActive) {
            continue;
          }

          if (String.isBlank(u.Email)) {
            continue;
          }

          request.resolvedToAddresses.add(u.Email.trim());
        }
      }
    }
  }

  private static Boolean isUser(Id recordId) {
    return recordId.getSObjectType() == User.SObjectType;
  }

  /**********************************************************************
   * RENDER EMAIL TEMPLATE
   *
   * Renders an Email Template and returns the rendered email.
   **********************************************************************/
  private static Messaging.SingleEmailMessage renderEmailTemplate(
    EmailRequest request
  ) {
    if (request.templateId == null) {
      return null;
    }
    
    return Messaging.renderStoredEmailTemplate(
      request.templateId,
      request.targetObjectId,
      request.whatId
    );
  }
  /**********************************************************************
   * BUILD EMAIL MESSAGES
   *
   * Builds a list of Messaging.SingleEmailMessage objects from EmailRequests.
   **********************************************************************/
  private static List<Messaging.SingleEmailMessage> buildEmails(
    List<EmailRequest> requests
  ) {
    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

    if (requests == null || requests.isEmpty()) {
      return emails;
    }

    for (EmailRequest request : requests) {
      emails.add(buildEmail(request));
    }

    return emails;
  }

  /**********************************************************************
   * BUILD SINGLE EMAIL
   *
   * Creates a Messaging.SingleEmailMessage from EmailRequest.
   **********************************************************************/
  private static Messaging.SingleEmailMessage buildEmail(EmailRequest request) {
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

    //==========================================================
    // Template / Content
    //==========================================================

    if (request.templateId != null) {
      if (request.renderTemplate) {
        Messaging.SingleEmailMessage renderedEmail = renderEmailTemplate(
          request
        );

        email.setSubject(
          String.isBlank(request.subject)
            ? renderedEmail.getSubject()
            : request.subject
        );

        if (!String.isBlank(renderedEmail.getHtmlBody())) {
          email.setHtmlBody(renderedEmail.getHtmlBody());
        }

        if (!String.isBlank(renderedEmail.getPlainTextBody())) {
          email.setPlainTextBody(renderedEmail.getPlainTextBody());
        }

        email.setTreatTargetObjectAsRecipient(false);
      } else {
        email.setTemplateId(request.templateId);

        email.setTargetObjectId(request.targetObjectId);

        email.setTreatTargetObjectAsRecipient(
          request.treatTargetObjectAsRecipient
        );

        if (request.whatId != null) {
          email.setWhatId(request.whatId);
        }
      }
    } else {
      if (!String.isBlank(request.subject)) {
        email.setSubject(request.subject);
      }

      if (!String.isBlank(request.body)) {
        email.setPlainTextBody(request.body);
      }

      if (!String.isBlank(request.htmlBody)) {
        email.setHtmlBody(request.htmlBody);
      }

      if (request.targetObjectId != null) {
        email.setTargetObjectId(request.targetObjectId);

        email.setTreatTargetObjectAsRecipient(
          request.treatTargetObjectAsRecipient
        );
      }

      if (request.whatId != null) {
        email.setWhatId(request.whatId);
      }
    }

    //==========================================================
    // Recipients
    //==========================================================

    if (!request.resolvedToAddresses.isEmpty()) {
      email.setToAddresses(request.resolvedToAddresses);
    }

    if (!request.resolvedCcAddresses.isEmpty()) {
      email.setCcAddresses(request.resolvedCcAddresses);
    }

    if (!request.resolvedBccAddresses.isEmpty()) {
      email.setBccAddresses(request.resolvedBccAddresses);
    }

    //==========================================================
    // Email Settings
    //==========================================================

    email.setSaveAsActivity(request.saveAsActivity);

    email.setUseSignature(request.useSignature);

    if (!String.isBlank(request.replyTo)) {
      email.setReplyTo(request.replyTo);
    }

    if (!String.isBlank(request.senderDisplayName)) {
      email.setSenderDisplayName(request.senderDisplayName);
    }

    if (request.orgWideEmailAddressId != null) {
      email.setOrgWideEmailAddressId(request.orgWideEmailAddressId);
    }

    //==========================================================
    // Attachments
    //==========================================================

    List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();

    attachments.addAll(request.attachments);
    attachments.addAll(request.resolvedAttachments);

    System.debug(
      'Attachments Before setFileAttachments: ' + attachments.size()
    );

    for (Messaging.EmailFileAttachment a : attachments) {
      System.debug('Sending Attachment: ' + a.getFileName());
      System.debug('Size: ' + a.getBody().size());
    }

    if (!attachments.isEmpty()) {
      email.setFileAttachments(attachments);
    }

    email.setFileAttachments(attachments);

    System.debug('setFileAttachments completed.');

    return email;
  }

  /**********************************************************************
   * ATTACHMENTS
   **********************************************************************/

  /**********************************************************************
   * RESOLVE CONTENT VERSION ATTACHMENTS
   *
   * Converts ContentVersion records into EmailFileAttachments.
   **********************************************************************/
  /**********************************************************************
   * RESOLVE ATTACHMENTS
   *
   * Supports:
   * 1. Existing EmailFileAttachment
   * 2. ContentVersion
   * 3. ContentDocument (Latest Version)
   * 4. Blob Attachments (VF PDF, Generated Files, etc.)
   **********************************************************************/
  private static void resolveAttachments(List<EmailRequest> requests) {
    Set<Id> contentVersionIds = new Set<Id>();
    Set<Id> contentDocumentIds = new Set<Id>();

    // Collect Ids
    for (EmailRequest request : requests) {
      contentVersionIds.addAll(request.contentVersionIds);
      contentDocumentIds.addAll(request.contentDocumentIds);
    }

    //==========================================================
    // Resolve ContentDocument -> LatestPublishedVersionId
    //==========================================================

    Map<Id, Id> documentToVersionMap = new Map<Id, Id>();

    if (!contentDocumentIds.isEmpty()) {
      for (ContentDocument doc : [
        SELECT Id, LatestPublishedVersionId
        FROM ContentDocument
        WHERE Id IN :contentDocumentIds
      ]) {
        documentToVersionMap.put(doc.Id, doc.LatestPublishedVersionId);

        if (doc.LatestPublishedVersionId != null) {
          contentVersionIds.add(doc.LatestPublishedVersionId);
        }
      }
    }

    //==========================================================
    // Query all ContentVersions once
    //==========================================================

    Map<Id, ContentVersion> versionMap = new Map<Id, ContentVersion>();

    if (!contentVersionIds.isEmpty()) {
      versionMap = new Map<Id, ContentVersion>(
        [
          SELECT Id, Title, FileExtension, VersionData
          FROM ContentVersion
          WHERE Id IN :contentVersionIds
        ]
      );
    }

    //==========================================================
    // Build Attachments
    //==========================================================

    for (EmailRequest request : requests) {
      //------------------------------
      // ContentVersion
      //------------------------------

      for (Id versionId : request.contentVersionIds) {
        addContentVersionAttachment(request, versionMap.get(versionId));
      }

      //------------------------------
      // ContentDocument
      //------------------------------

      for (Id documentId : request.contentDocumentIds) {
        Id versionId = documentToVersionMap.get(documentId);

        addContentVersionAttachment(request, versionMap.get(versionId));
      }

      //------------------------------
      // Blob Attachments
      //------------------------------

      for (BlobAttachment blobAttachment : request.blobAttachments) {
        if (blobAttachment == null || blobAttachment.body == null) {
          continue;
        }

        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();

        attachment.setBody(blobAttachment.body);

        attachment.setFileName(blobAttachment.fileName);

        if (!String.isBlank(blobAttachment.contentType)) {
          attachment.setContentType(blobAttachment.contentType);
        }

        request.resolvedAttachments.add(attachment);

        System.debug(
          'Resolved Attachments Count: ' + request.resolvedAttachments.size()
        );

        for (Messaging.EmailFileAttachment a : request.resolvedAttachments) {
          System.debug('Attachment Name: ' + a.getFileName());
          System.debug('Attachment Body Size: ' + a.getBody().size());
        }
      }
    }
  }

  /**********************************************************************
   * HELPERS
   **********************************************************************/
  /**********************************************************************
   * ADD CONTENT VERSION ATTACHMENT
   **********************************************************************/
  private static void addContentVersionAttachment(
    EmailRequest request,
    ContentVersion version
  ) {
    if (version == null) {
      return;
    }

    Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();

    attachment.setBody(version.VersionData);

    String fileName = version.Title;

    if (!String.isBlank(version.FileExtension)) {
      fileName += '.' + version.FileExtension;
    }

    attachment.setFileName(fileName);

    request.resolvedAttachments.add(attachment);
  }

  /**********************************************************************
   * REMOVE DUPLICATE EMAILS
   *
   * Removes:
   *  - Blank values
   *  - Duplicate values
   *  - Invalid email addresses
   **********************************************************************/
  private static List<String> removeDuplicates(List<String> emails) {
    List<String> results = new List<String>();

    if (emails == null || emails.isEmpty()) {
      return results;
    }

    Set<String> uniqueEmails = new Set<String>();

    for (String email : emails) {
      if (String.isBlank(email)) {
        continue;
      }

      email = email.trim().toLowerCase();

      if (!isValidEmail(email)) {
        continue;
      }

      uniqueEmails.add(email);
    }

    results.addAll(uniqueEmails);

    results.sort();

    return results;
  }

  /**********************************************************************
   * VALIDATE EMAIL ADDRESS
   **********************************************************************/
  private static Boolean isValidEmail(String email) {
    return !String.isBlank(email) &&
      EMAIL_PATTERN.matcher(email.trim()).matches();
  }

  /**********************************************************************
   * REQUEST WRAPPER
   **********************************************************************/

  public class BlobAttachment {
    public String fileName;

    public Blob body;

    public String contentType;
  }

  public class EmailRequest {
    // Template
    public Id templateId;
    public String templateDeveloperName;

    // Content
    public String subject;
    public String body;
    public String htmlBody;

    // Merge Fields
    public Id targetObjectId;
    public Id whatId;

    // Raw Email Addresses
    public List<String> toAddresses = new List<String>();
    public List<String> ccAddresses = new List<String>();
    public List<String> bccAddresses = new List<String>();

    // Salesforce Recipients
    public List<Id> userIds = new List<Id>();
    public List<Id> queueIds = new List<Id>();

    // Framework populated
    public List<String> resolvedToAddresses = new List<String>();
    public List<String> resolvedCcAddresses = new List<String>();
    public List<String> resolvedBccAddresses = new List<String>();

    // Email Options
    public Boolean saveAsActivity = true;
    public Boolean useSignature = false;
    public Boolean includeQueueMembers = true;
    public Boolean allOrNothing = false;

    // Email Settings
    public String replyTo;
    public String senderDisplayName;
    public Id orgWideEmailAddressId;
    public Boolean treatTargetObjectAsRecipient = true;

    // Template Options
    public Boolean renderTemplate = false;

    // Queue Options
    public Boolean sendToQueueEmail = false;

    // Attachments
    public List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();

    public List<Id> contentVersionIds = new List<Id>();

    public List<Messaging.EmailFileAttachment> resolvedAttachments = new List<Messaging.EmailFileAttachment>();

    public List<Id> contentDocumentIds = new List<Id>();

    public List<BlobAttachment> blobAttachments = new List<BlobAttachment>();
  }

  /**********************************************************************
   * RESULT
   **********************************************************************/

  public class EmailResult {
    public Boolean success;

    public String errorMessage;

    public EmailRequest request;

    public Messaging.SendEmailResult salesforceResult;
  }

  /**********************************************************************
   * EXCEPTION
   **********************************************************************/

  public class EmailFrameworkException extends Exception {
  }
}
