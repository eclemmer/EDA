public class FlowLauncher {

    @AuraEnabled
    public static void getImpactedContactIdsByFacilityModel(String campaignId, List<String> slackChannels) {
        try {
            FlowLauncher.start(campaignId, slackChannels);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static void start(String campaignId, List<String> slackChannels) {
        List<slackv2__Message_Destination__c> destinations = [
            SELECT Id
            FROM slackv2__Message_Destination__c
            WHERE Id IN: slackChannels
        ];
        Campaign cmp = [SELECT Id FROM Campaign WHERE Id = :campaignId];
        Map<String, Object> myMap = new Map<String, Object>();
        myMap.put('Destinations', destinations);
        myMap.put('Record', cmp);
        Flow.Interview myFlow = new Flow.Interview.Send_Slack_Alert(myMap);
        myFlow.start();
    }
}