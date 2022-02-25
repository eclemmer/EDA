public with sharing class CampaignFacilityEventController {

    public static List<FacilityModel> getFacilityModels(Id campaignId) {
        try {
            Set<Id> facilityIds = CampaignFacilityEventController.getFacilityIdsFromCampaignId(campaignId);

            if(facilityIds.isEmpty()) {
                return new List<FacilityModel>();
            }

            List<Facility__c> allFacilities = CampaignFacilityEventController.getAllFacilitiesFromParentFacilityIds(facilityIds);

            if(allFacilities.isEmpty()) {
                return new List<FacilityModel>();
            }

            List<FacilityModel> facilityModels = CampaignFacilityEventController.getFacilityModelsFromFacilities(allFacilities);
            return facilityModels;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    //Gets all facility ids from Campaign -> Facility Even -> Facility Event Participation -> Facility
    public static Set<Id> getFacilityIdsFromCampaignId(Id campaignId) {
        Map<Id,Facility_Event__c> facilityEvents = new Map<Id,Facility_Event__c>([
            SELECT Id
            FROM Facility_Event__c
            WHERE Campaign__c = :campaignId]);
        
        if(facilityEvents.isEmpty()) {
            return new Set<Id>();
        }

        Map<Id,Facility_Event_Participation__c> facilityEventParticipations = new Map<Id,Facility_Event_Participation__c>([
            SELECT Id,
                Facility__c
            FROM Facility_Event_Participation__c
            WHERE Facility_Event__c IN :facilityEvents.keySet()
        ]);
        
        if(facilityEventParticipations.isEmpty()) {
            return new Set<Id>();
        }

        //Set to ensure uniqueness
        Set<Id> facilityIds = new Set<Id>();
        for(Facility_Event_Participation__c facilityEventParticipation : facilityEventParticipations.values()) {
            facilityIds.add(facilityEventParticipation.Facility__c);
        }
        return facilityIds;
    }

    //Gets all Facilities recursively in a list order of parent, child, grandchild, etc
    public static List<Facility__c> getAllFacilitiesFromParentFacilityIds(Set<Id> facilityIds) {
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
                WHERE Id IN :currentFacilities.keySet()
            ]);
        }

        return allFacilities;
    }

    //Gets all facilities starting from parent facilities in an ordered list
    public static List<FacilityModel> getFacilityModelsFromFacilities(List<Facility__c> allFacilities) {
        List<FacilityModel> baseFacilityModels = new List<FacilityModel>();
        Map<Id,FacilityModel> FacilityModelsByFacilityIds = new Map<Id,FacilityModel>();

        for(Facility__c currentFacility : allFacilities) {
            FacilityModel currentFacilityModel = new FacilityModel(currentFacility);

            if(currentFacility.Parent_Facility__c == null) {
                //parents go into the top-level list
                baseFacilityModels.add(currentFacilityModel);
                continue;
            }

            //children go into the parent's child list
            //We ensured a list order that guarantees the parent is already processed in the get facilities method
            FacilityModel parentFacilityModel = FacilityModelsByFacilityIds.get(currentFacility.Parent_Facility__c);
            parentFacilityModel.children.add(currentFacilityModel);
        }

        return baseFacilityModels;
    }
}