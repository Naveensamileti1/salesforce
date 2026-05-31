public with sharing class AccountDetailsVfController {
  private Id accountId;
  private AccountDetailsVfWrapper accountDetails;

  public AccountDetailsVfController() {
    accountId = ApexPages.currentPage().getParameters().get('accountId');
  }

  public AccountDetailsVfWrapper getAccountDetails() {
    if(accountId == null) {
      ApexPages.Message msg = new ApexPages.Message(
        ApexPages.Severity.ERROR,
        'No Account Id provided in the URL.'
      );
      ApexPages.addMessage(msg);
      return null;
    }
    if (accountDetails == null) {
      accountDetails = buildAccountDetails();
    }

    return accountDetails;
  }

  private AccountDetailsVfWrapper buildAccountDetails() {
    if (accountId == null) {
      return null;
    }

    List<Account> accounts = [
      SELECT
        Name,
        Phone,
        Type,
        BillingStreet,
        BillingCity,
        BillingState,
        BillingPostalCode,
        BillingCountry,
        ShippingStreet,
        ShippingCity,
        ShippingState,
        ShippingPostalCode,
        ShippingCountry
      FROM Account
      WHERE Id = :accountId
      LIMIT 1
    ];

    if (accounts.isEmpty()) {
      return null;
    }

    Account accDetails = accounts[0];

    AccountDetailsVfWrapper wrapper = new AccountDetailsVfWrapper();

    wrapper.acc = new AccountWrapper();

    // Account Details
    wrapper.acc.accName = accDetails.Name;
    wrapper.acc.accPhone = accDetails.Phone;
    wrapper.acc.accType = accDetails.Type;

    wrapper.acc.billingAddress = buildAddress(
      accDetails.BillingStreet,
      accDetails.BillingCity,
      accDetails.BillingState,
      accDetails.BillingPostalCode,
      accDetails.BillingCountry
    );

    wrapper.acc.shippingAddress = buildAddress(
      accDetails.ShippingStreet,
      accDetails.ShippingCity,
      accDetails.ShippingState,
      accDetails.ShippingPostalCode,
      accDetails.ShippingCountry
    );

    // Contacts
    wrapper.lstContact = [
      SELECT Id, Name, Email, Phone, Title
      FROM Contact
      WHERE AccountId = :accountId
      ORDER BY Name
    ];

    // Opportunity Products
    wrapper.lstOppLineItem = [
      SELECT
        Id,
        Quantity,
        UnitPrice,
        TotalPrice,
        Opportunity.Name,
        PricebookEntry.Product2.Name
      FROM OpportunityLineItem
      WHERE Opportunity.AccountId = :accountId
      ORDER BY Opportunity.Name
    ];

    return wrapper;
  }

  private String buildAddress(
    String street,
    String city,
    String state,
    String postalCode,
    String country
  ) {
    List<String> parts = new List<String>();

    if (String.isNotBlank(street)) {
      parts.add(street);
    }

    if (String.isNotBlank(city)) {
      parts.add(city);
    }

    if (String.isNotBlank(state)) {
      parts.add(state);
    }

    if (String.isNotBlank(postalCode)) {
      parts.add(postalCode);
    }

    if (String.isNotBlank(country)) {
      parts.add(country);
    }

    return String.join(parts, ', ');
  }

  public class AccountWrapper {
    public String accName { get; set; }

    public String accPhone { get; set; }

    public String accType { get; set; }

    public String billingAddress { get; set; }

    public String shippingAddress { get; set; }
  }

  public class AccountDetailsVfWrapper {
    public AccountWrapper acc { get; set; }

    public List<Contact> lstContact { get; set; }

    public List<OpportunityLineItem> lstOppLineItem { get; set; }
  }
}
