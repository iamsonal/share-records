/**
 * Created by sonal on 8/25/2022.
 */

public with sharing class SObjectShareController {
    private final static Integer MAX_RESULTS = 5;

    @AuraEnabled(Cacheable=true Scope='global')
    public static List<LookupResults> search(String searchTerm, List<String> selectedIds) {
        searchTerm += '*';

        List<List<SObject>> searchResults = [
            FIND :searchTerm
            IN ALL FIELDS
            RETURNING User(Id, FirstName, LastName, UserName WHERE IsActive = TRUE AND Id NOT IN :selectedIds)
            LIMIT :MAX_RESULTS
        ];

        List<LookupResults> results = new List<LookupResults>();

        String userIcon = 'standard:user';
        User[] users = (List<User>) searchResults[0];
        for (User vUser : users) {
            String subtitle = vUser.LastName == null ? 'User' : 'User • ' + vUser.Username;
            results.add(new LookupResults(vUser.Id, 'User', userIcon, vUser.FirstName + ' ' + vUser.LastName, subtitle));
        }

        results.sort();

        return results;
    }

    @AuraEnabled
    public static void removeShare(Id recordId) {
        Database.DeleteResult[] deleteResults = Database.delete(new List<Id>{ recordId }, true);
        for (Database.DeleteResult dr : deleteResults) {
            if (!dr.isSuccess()) {
                for (Database.Error err : dr.getErrors()) {
                    throw new AuraHandledException(err.getMessage());
                }
            }
        }
    }

    @AuraEnabled(Cacheable=true)
    public static Response validateUser(Id recordId, String sObjectName) {
        UserRecordAccess access = [
            SELECT HasAllAccess, HasDeleteAccess, RecordId
            FROM UserRecordAccess
            WHERE UserId = :UserInfo.getUserId() AND RecordId = :recordId
        ];

        if (!access.HasAllAccess && !access.HasDeleteAccess) {
            return new Response(true, 'User cannot share this record with other users.');
        }

        // If there are no records in share object, then sharing is read-write for this object, and so sharing is not required
        String shareObjectName = getSharingObjectName(sObjectName);
        String query = 'SELECT COUNT() FROM ' + shareObjectName;
        Integer count = Database.countQuery(query);
        if (count == 0) {
            return new Response(true, 'Manual sharing is not allowed for this object.');
        }

        return new Response(false, null);
    }

    @AuraEnabled
    public static List<ShareRecord> getSObjectShares(Id recordId, String sObjectName) {
        String shareSObjectName = getSharingObjectName(sObjectName);

        // Get all the fields from Share object
        Set<String> sObjectFields = Schema.getGlobalDescribe().get(shareSObjectName).getDescribe().fields.getMap().keySet();
        List<String> fieldsInList = new List<String>(sObjectFields);

        // ** Considering only RowCauses as Manual and Owner
        List<String> rowCauses = new List<String>{ 'Manual', 'Owner' };

        String queryTemplate = 'SELECT {0} FROM {1} WHERE {2} = :recordId AND RowCause IN :rowCauses';
        String query = String.format(queryTemplate, new List<String>{ String.join(fieldsInList, ','), shareSObjectName, sObjectName + 'Id' });
        List<SObject> sObjectShares = Database.query(query);

        Set<String> userIds = new Set<String>();
        for (SObject share : sObjectShares) {
            userIds.add(String.valueOf(share.get('UserOrGroupId')));
        }

        List<ShareRecord> shareRecords = new List<ShareRecord>();
        if (userIds.isEmpty()) {
            return shareRecords;
        }

        // Querying Name of a user to display in the UI datatable
        Map<Id, User> usersByIds = new Map<Id, User>([SELECT Id, Name FROM User WHERE Id IN :userIds]);

        for (SObject share : sObjectShares) {
            Map<String, Object> shareMap = share.getPopulatedFieldsAsMap();
            ShareRecord shareRecord = new ShareRecord();
            shareRecord.id = String.valueOf(shareMap.get('Id'));

            if (String.valueOf(shareMap.get('RowCause')) == 'Manual') {
                shareRecord.actionDisabled = false;
            }

            shareRecord.userOrGroupId = String.valueOf(shareMap.get('UserOrGroupId'));

            // Looping over AccessLevel fields on a Share object
            Set<String> accessLevelKeys = new Set<String>();
            for (String key : shareMap.keySet()) {
                if (key.endsWith('AccessLevel')) {
                    accessLevelKeys.add(key);
                }
            }

            Map<String, String> accessLevelsMap = new Map<String, String>();
            for (String accessLevelKey : accessLevelKeys) {
                accessLevelsMap.put(accessLevelKey, String.valueOf(shareMap.get(accessLevelKey)));
            }

            shareRecord.accessLevelMap = accessLevelsMap;
            shareRecord.userName = usersByIds.get((Id) shareMap.get('UserOrGroupId')).Name;

            shareRecords.add(shareRecord);
        }

        return shareRecords;
    }

    @AuraEnabled
    public static void updateSObjectShares(List<Id> userIds, Map<String, String> accessLevels, Id recordId, String sObjectName, Boolean sendEmail) {
        List<SObject> sObjectShares = new List<SObject>();

        for (Id userId : userIds) {
            SObject sObjectShare = Schema.getGlobalDescribe().get(sObjectName + 'Share').newSObject();
            for (String level : accessLevels.keySet()) {
                sObjectShare.put(level, accessLevels.get(level));
            }
            sObjectShare.put('UserOrGroupId', userId);
            sObjectShare.put(sObjectName + 'Id', recordId);

            sObjectShares.add(sObjectShare);
        }

        try {
            insert sObjectShares;

            if (sendEmail) {
                SObjectShareService.sendEmail(userIds, recordId, sObjectName);
            }
            SObjectShareService.notifyUsers(userIds, recordId, sObjectName);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static String getSharingObjectName(String sObjectName) {
        if (sObjectName.contains('__c')) {
            return sObjectName.replace('__c', '__Share');
        } else {
            return sObjectName + 'Share';
        }
    }

    public class ShareRecord {
        @AuraEnabled
        public Map<String, String> accessLevelMap { get; set; }
        @AuraEnabled
        public Id id { get; set; }
        @AuraEnabled
        public String userName { get; set; }
        @AuraEnabled
        public Id userOrGroupId { get; set; }
        @AuraEnabled
        public Boolean actionDisabled { get; set; }

        public ShareRecord() {
            this.actionDisabled = true;
        }
    }

    public class Response {
        @AuraEnabled
        public Boolean isError { get; set; }
        @AuraEnabled
        public String message { get; set; }

        public Response(Boolean isError, String message) {
            this.isError = isError;
            this.message = message;
        }
    }
}
