public with sharing class CampaignFacilityEventController {

    @AuraEnabled
    public static List<FacilityModel> getFacilityModels(Id campaignId) {
        try {
            Map<Id,Facility_Event__c> facilityEventsByFacilityIds = CampaignFacilityEventController.getFacilityEventsByFacilityIdsFromCampaignId(campaignId);

            if(facilityEventsByFacilityIds.isEmpty()) {
                return new List<FacilityModel>();
            }

            List<Facility__c> allFacilities = CampaignFacilityEventController.getAllFacilitiesFromParentFacilityIds(facilityEventsByFacilityIds.keySet());

            if(allFacilities.isEmpty()) {
                return new List<FacilityModel>();
            }

            List<FacilityModel> facilityModels = CampaignFacilityEventController.getFacilityModelsFromFacilities(allFacilities,facilityEventsByFacilityIds);
            return facilityModels;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    //Gets a map of Facility Events by Facility ids from Campaign -> Facility Event -> Facility Event Participation -> Facility
    private static Map<Id,Facility_Event__c> getFacilityEventsByFacilityIdsFromCampaignId(Id campaignId) {
        Map<Id,Facility_Event__c> facilityEventsByIds = new Map<Id,Facility_Event__c>([
            SELECT Id,
                Event_Start__c,
                Event_End__c
            FROM Facility_Event__c
            WHERE Campaign__c = :campaignId]);
        
        if(facilityEventsByIds.isEmpty()) {
            return new Map<Id,Facility_Event__c>();
        }

        Map<Id,Facility_Event_Participation__c> facilityEventParticipations = new Map<Id,Facility_Event_Participation__c>([
            SELECT Id,
                Facility__c,
                Facility_Event__c
            FROM Facility_Event_Participation__c
            WHERE Facility_Event__c IN :facilityEventsByIds.keySet()
        ]);
        
        if(facilityEventParticipations.isEmpty()) {
            return new Map<Id,Facility_Event__c>();
        }

        Map<Id,Facility_Event__c> facilityEventsByFacilityIds = new Map<Id,Facility_Event__c>();

        for(Facility_Event_Participation__c currentFacilityEventParticipation : facilityEventParticipations.values()) {
            //TODO: Properly support a multiplicity of Facility Events here as we can lose time tracking
            facilityEventsByFacilityIds.put(currentFacilityEventParticipation.Facility__c, facilityEventsByIds.get(currentFacilityEventParticipation.Facility_Event__c));
        }

        return facilityEventsByFacilityIds;
    }

    //Gets all Facilities recursively in a list order of parent, child, grandchild, etc
    private static List<Facility__c> getAllFacilitiesFromParentFacilityIds(Set<Id> facilityIds) {
        //Map to permit for recursive keysets
        Map<Id, Facility__c> currentFacilities = new Map<Id, Facility__c>([
            SELECT Id,
                Name,
                Parent_Facility__c
            FROM Facility__c
            WHERE Id IN :facilityIds
        ]);

        //Use this for a deliberate iteration sort the map does not provide
        List<Facility__c> allFacilities = new List<Facility__c>();

        //Though this is an iteration for an arbitrary nesting, this should not exceed the SOQL query limits
        WHILE(currentFacilities.isEmpty() == false) {
            //This saves cycles as we will reenter the loop and apply similar logic
            allFacilities.addAll(currentFacilities.values());                
            currentFacilities = new Map<Id, Facility__c>([
                SELECT Id,
                    Name,
                    Parent_Facility__c
                FROM Facility__c
                WHERE Parent_Facility__c IN :currentFacilities.keySet()
            ]);
        }

        return allFacilities;
    }

    //Gets all facilities starting from parent facilities in an ordered list
    private static List<FacilityModel> getFacilityModelsFromFacilities(List<Facility__c> allFacilities, Map<Id,Facility_Event__c> facilityEventsByFacilityIds) {
        List<FacilityModel> baseFacilityModels = new List<FacilityModel>();
        Map<Id,FacilityModel> facilityModelsByFacilityIds = new Map<Id,FacilityModel>();

        for(Facility__c currentFacility : allFacilities) {
            FacilityModel currentFacilityModel = new FacilityModel(currentFacility,facilityEventsByFacilityIds.get(currentFacility.Id));
            //We ensured a list order that guarantees the parent is already processed in the get facilities method
            FacilityModel parentFacilityModel = facilityModelsByFacilityIds.get(currentFacility.Parent_Facility__c);

            if(parentFacilityModel == null) {
                //parents go into the top-level list
                baseFacilityModels.add(currentFacilityModel);
                continue;
            }

            //children go into the parent's child list
            parentFacilityModel.children.add(currentFacilityModel);
        }

        return baseFacilityModels;
    }
}