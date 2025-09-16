# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      module Templates
        class GenerateCubeQuery
          def initialize(user_input)
            @user_input = user_input
          end

          def to_prompt
            <<~PROMPT
You are an assistant tasked with converting plain text questions about event data in to a structured query in JSON format. I will provide information about the permitted schema and then ask you to generate a query based on a single question.

The root-level keys and their types are:

measures: An array of measures.
dimensions: An array of dimensions.
timeDimensions: A convenient way to specify a time dimension with a filter
limit: A row limit for your query. The default value is 10000. The maximum allowed limit is 50000.
order: An object, where the keys are measures or dimensions to order by and their corresponding values are either asc or desc. The order of the fields to order on is based on the order of the keys in the object

"measures" must be one or more of the following:

"TrackedEvents.pageViewsCount" which counts the number of page views
"TrackedEvents.uniqueUsersCount" which counts the number of unique users
"TrackedEvents.linkClicksCount" which counts the number of clicks on links
"TrackedEvents.count" which counts the number of events
"Sessions.count" which counts the number of sessions
"Sessions.averagePerUser" which counts the average number of sessions per user
"Sessions.averageDurationMinutes" which counts the average duration of sessions in minutes
"Sessions.uniqueUsersCount" which counts the number of unique users who had sessions
"Sessions.usersCount" which counts the number of non-unique users who had sessions
"ReturningUsers.allSessionsCount" which counts the number of sessions for returning users
"ReturningUsers.returningUserPercentage" which counts the percentage of returning users.

"dimensions" must be zero or more of the following:

"TrackedEvents.pageUrlhosts"
"TrackedEvents.pageUrlpath" which refers to a page path or unique page
"TrackedEvents.event"
"TrackedEvents.eventId"
"TrackedEvents.eventName"
"TrackedEvents.pageTitle"
"TrackedEvents.osFamily"
"TrackedEvents.osName"
"TrackedEvents.osVersion"
"TrackedEvents.osVersionMajor"
"TrackedEvents.agentName"
"TrackedEvents.agentVersion"
"TrackedEvents.pageReferrer"
"TrackedEvents.pageUrl" which is a full url
"TrackedEvents.baseUrl" which is the protocol, host and port of the url
"TrackedEvents.useragent"
"TrackedEvents.derivedTstamp"
"TrackedEvents.browserLanguage"
"TrackedEvents.documentLanguage"
"TrackedEvents.viewportSize"
"TrackedEvents.targetUrl"
"TrackedEvents.elementId"
"TrackedEvents.customEventName"
"TrackedEvents.customEventProps"
"TrackedEvents.customUserProps"
"TrackedEvents.userId"
"Sessions.startAt"
"Sessions.userId"
"Sessions.sessionID"
"Sessions.endAt"
"Sessions.agentName" which is the browser or other agent triggering the event
"Sessions.osFamily"
"Sessions.osName"
"Sessions.osVersion"
"Sessions.osVersionMajor"
"Sessions.agentVersion"
"Sessions.browserLanguage"
"Sessions.documentLanguage"
"Sessions.viewportSize"
"ReturningUsers.first_timestamp"

"timeDimensions" is an array of zero or more JSON objects with the following root keys, all of which are mandatory:

"dimension" is a single dimension from the list of acceptable dimensions above.
"dateRange" is an array of two dates between which data is returned. They MUST be in the format YYYY-MM-DD. Alternatively "date range" can be a single string to represent a date range such as "last week" or "this month".
"granularity" is the granularity of the results. Pick something sensible for this value from "hour", "day", "week" or "month"

Do not include "null" in any part of your response.

The question you need to answer is "#{@user_input}"

Please provide the response wrapped in nothing.
            PROMPT
          end
        end
      end
    end
  end
end
