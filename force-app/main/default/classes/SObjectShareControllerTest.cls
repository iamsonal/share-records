/**
 * Created by sonal on 8/27/2022.
 */
@IsTest
public with sharing class SObjectShareControllerTest {
    @TestSetup
    private static void setupTestUsers() {
        Id profileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id;

        User vUser = new User(
            ProfileId = profileId,
            FirstName = 'Test',
            LastName = 'Test',
            Email = 'user@sf.com',
            Username = 'user@sf.com',
            CompanyName = 'company',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            IsActive = true
        );
        insert vUser;
    }

    @IsTest
    public static void searchTest() {
        List<LookupResults> results = SObjectShareController.search('Test', new List<Id>());
        System.assertEquals(0, results.size());
    }

    @IsTest
    public static void getSObjectSharesTest() {
        Account vAccount = new Account(Name = 'Test Account');
        insert vAccount;

        List<SObjectShareController.ShareRecord> shareRecords = SObjectShareController.getSObjectShares(vAccount.Id, 'Account');
        System.assertEquals(1, shareRecords.size());
        System.assertEquals(UserInfo.getUserId(), shareRecords[0].userOrGroupId);
        System.assertEquals('All', shareRecords[0].accessLevelMap.get('AccountAccessLevel'));
    }

    @IsTest
    public static void updateSObjectSharesTest() {
        Account vAccount = new Account(Name = 'Demo Account');
        insert vAccount;

        Map<String, String> accessLevels = new Map<String, String>();
        accessLevels.put('AccountAccessLevel', 'Read');
        accessLevels.put('CaseAccessLevel', 'None');
        accessLevels.put('OpportunityAccessLevel', 'None');

        User vUser = [SELECT Id FROM User WHERE Username = 'user@sf.com' LIMIT 1];

        SObjectShareController.updateSObjectShares(new List<Id>{ vUser.Id }, accessLevels, vAccount.Id, 'Account', true);

        List<AccountShare> accountShares = [SELECT Id, RowCause, UserOrGroupId FROM AccountShare WHERE AccountId = :vAccount.Id];
        System.assertEquals(2, accountShares.size());
    }

    @IsTest
    public static void validateUserTest() {
        Account vAccount = new Account(Name = 'Test');
        insert vAccount;

        SObjectShareController.Response response = SObjectShareController.validateUser(vAccount.Id, 'Account');
        System.assertEquals(false, response.isError);
    }
}
