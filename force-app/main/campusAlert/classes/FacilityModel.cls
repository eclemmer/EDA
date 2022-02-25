public with sharing class FacilityModel {
    @AuraEnabled public String id;
    @AuraEnabled public String label;
    @AuraEnabled public Integer totalStudents;
    @AuraEnabled public List<FacilityModel> children { get; private set; }
    public FacilityModel() {}


    public FacilityModel(Facility__c facility) {
        this.id = facility.Id;
        this.label = facility.Name;
        this.totalStudents = 0;
        this.children = new List<FacilityModel>();
    }
}
