public with sharing class FacilityModel {
    @AuraEnabled public String id;
    @AuraEnabled public String label;
    @AuraEnabled public Datetime eventStart;
    @AuraEnabled public Datetime eventEnd;
    @AuraEnabled public Integer totalStudents;
    @AuraEnabled public List<FacilityModel> children { get; private set; }
    public FacilityModel() {}


    public FacilityModel(Facility__c facility, Facility_Event__c facilityEvent) {
        this.id = facility.Id;
        this.label = facility.Name;
        this.eventStart = facilityEvent.Event_Start__c;
        this.eventEnd = facilityEvent.Event_End__c;
        this.totalStudents = 0;
        this.children = new List<FacilityModel>();
    }
}
