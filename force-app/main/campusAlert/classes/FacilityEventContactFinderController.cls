public with sharing class FacilityEventContactFinderController {

    private static String courseOfferingScheduleQuery = 'SELECT '
        + 'Id, '
        + 'Course_Offering__c '
        + 'FROM Course_Offering_Schedule__c '
        + 'WHERE DAYTOKEN = TRUE'
        + 'AND ('
            //Event between
            + '('
                + 'Start_Time__c <= :eventTimeSpan.eventStartTime'
                + 'AND End_Time__c >= :eventTimeSpan.eventEndTime'
            + ') OR ('
            //Event starts before, ends during
            + '('
                + 'Start_Time__c >= :eventTimeSpan.eventStartTime'
                + 'AND Start_Time__c <= :eventTimeSpan.eventEndTime'
            + ') OR ('
            //Event starts during, ends after
            + '('
                + 'End_Time__c >= :eventTimeSpan.eventStartTime'
                + 'AND End_Time__c <= :eventTimeSpan.eventEndTime'
            + ')'
        + ')';

    public static Set<Id> getImpactedContactIdsByFacilityModel(FacilityModel facilityModel) {
        try {
            return FacilityEventContactFinderController.getContactsFromFacilityModel(facilityModel);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    //Get all affected people by Facility -> Course Offering Schedule -> Course Offering -> Course Connection -> Contact
    private static Set<Id> getContactsFromFacilityModel(FacilityModel facilityModel) {
        CourseTimeModel eventTimespan = new CourseTimeModel(facilityModel);

        //TODO: Add support for time blocks, should be trivial

        //Get Course Offering Schedules in Timeframe
        //TODO: Add support for multiday events
        List<Course_Offering_Schedule__c> courseOfferingSchedulesInTime = Database.query(
            courseOfferingScheduleQuery.replace('DAYTOKEN',eventTimespan.courseOfferingEventStartDayField));

        if(courseOfferingSchedulesInTime.isEmpty()) {
            return new Set<Id>();
        }

        //Extract Course Offering Ids. This lets us skip an entire object query and go straight to Course Connection
        Set<Id> relevantCourseOfferingIds = new Set<Id>();
        for(Course_Offering_Schedule__c courseOfferingScheduleToProcess : courseOfferingSchedulesInTime) {
            relevantCourseOfferingIds.add(courseOfferingScheduleToProcess.Course_Offering__c);
        }

        //Get course connections based on course offerings
        //TODO: Add configuration setting for relevant Course Connection Statuses
        List<Course_Enrollment__c> relevantCourseConnections = [
            SELECT Id,
            Contact__c
            FROM Course_Enrollment__c
            WHERE Course_Offering__c IN :relevantCourseOfferingIds
        ];

        if(relevantCourseConnections.isEmpty()) {
            return new Set<Id>();
        }

        //Extract Contact Ids
        Set<Id> relevantContactIds = new Set<Id>();
        for(Course_Enrollment__c courseConnectionToProcess : relevantCourseConnections) {
            relevantContactIds.add(courseConnectionToProcess.Contact__c);
        }

        return relevantContactIds;
    }

    //Time model to handle course time for facilities
    private class CourseTimeModel {
        public Time eventStartTime;
        public Time eventEndTime;
        public String eventStartDayOfWeek;
        public String eventEndDayOfWeek;

        CourseTimeModel(FacilityModel facilityModel){
            //TODO: Make a determination on UTC vs course time, possibly with a setting

            this.eventStartTime = this.getTimeFromDateTime(facilityModel.eventStart);
            this.eventStartDayOfWeek = this.getDayOfWeekFromDateTime(facilityModel.eventStart);
            
            if(facilityModel.eventEnd == null) {
                //Shift this one millisecond to make it a legitimate time range. This works explicitly given we have no millisecond resolution on time creation
                this.eventEndTime = eventStartTime.addMilliseconds(1);
                this.eventEndDayOfWeek = eventStartDayOfWeek;
            } else {
                this.eventStartTime = this.getTimeFromDateTime(facilityModel.eventEnd);
                this.eventEndDayOfWeek = this.getDayOfWeekFromDateTime(facilityModel.eventEnd);
            }
        }

        private Time getTimeFromDateTime(DateTime dateTimeToProcess) {
            //Resolution is down to the minute deliberately
            return Time.newInstance(dateTimeToProcess.hour(), dateTimeToProcess.minute(), 0, 0);
        }

        private String getDayOfWeekFromDateTime(DateTime dateTimeToProcess) {
            return dateTimeToProcess.format('EEEE');
        }

        public String courseOfferingEventStartDayField {
            get {
                return eventStartDayOfWeek + '__c';
            }
        }

        public String courseOfferingEventEndDayField {
            get {
                return eventEndDayOfWeek + '__c';
            }
        }
    }
}
