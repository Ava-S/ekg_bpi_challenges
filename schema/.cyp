CREATE GRAPH TYPE BPIC17GraphType STRICT {
    // nodes
    (entryNode: Entry
        {OPEN activity STR, lifecycle STR, timestamp DATETIME, eventId STR, eventOrigin STR, action STR,
        case STR, applicationType STR, requestedAmount STR, resource STR, OPTIONAL loanGoal STR,
        OPTIONAL offeredAmount DOUBLE, OPTIONAL creditScore DOUBLE, OPTIONAL numberOfTerms INT,
        OPTIONAL monthlyCost DOUBLE, OPTIONAL offerId STR})
    (eventNode:Event {timestamp DATETIME}),
    (activityNode:Activity {name STR, lifecycle STR}),
    ABSTRACT (entityNode: Entity {sysId STR}),
    (applicationNode: entityNode:Application {loanGoal STR, applicationType STR, requestedAmount DOUBLE}),
    (workflowNode: entityNode:Workflow),
    (offerNode: entityNode:Offer
        {offeredAmount DOUBLE, numberOfTerms INT, creditScore DOUBLE, firstWithdrawalAmount DOUBLE}),
    (resourceNode: entityNode:Resource),
    // prevalence edges
    ABSTRACT (:entryNode) <- [entityPrevalenceRelation:prevalence) - (:entityNode),
    (:entryNode) <- [applicationPrevalenceRelation:entityPrevalenceRelation) - (:applicationNode),
    (:entryNode) <- [workflowPrevalenceRelation:entityPrevalenceRelation) - (:workflowNode),
    (:entryNode) <- [offerPrevalenceRelation:entityPrevalenceRelation) - (:offerNode),
    (:entryNode) <- [resourcePrevalenceRelation:entityPrevalenceRelation) - (:resourceNode)
    (:entryNode) <- [eventPrevalenceRelation:prevalence) - (:eventNode),

    // event type edge
    (:eventNode) - [eventActivityRelation:event_type] -> (:activityNode)

    // corr edges
    ABSTRACT (:eventNode) - [corrRelation:has_participant {OPTIONAL qualifier STR}] -> (:entityNode)
    (:eventNode) - [applicationCorrRelation:corrRelation] -> (:applicationNode),
    (:eventNode) - [workflowCorrRelation:corrRelation] -> (:workflowNode),
    (:eventNode) - [offerCorrRelation:corrRelation] -> (:offerNode),
    (:eventNode) - [resourceCorrRelation:corrRelation] -> (:resourceNode),

    // edges between entities
    (:workflowNode) - [applicationWorkflowRelation:part_of] -> (:applicationNode),
    (:offerNode) - [applicationOfferRelation:offer_of] -> (:applicationNode),


    //constraints
    // each entity n has a unique system id if the labels are the same
    // for any nodes n1 and n2 with the same labels, if n1 and n2 have the same value for the property sysId, then n1=n2
    FOR labels(n) WITHIN (n:entityType)
        IDENTIFIER n.sysId
    // each activity is identified by its name lifecycle
    FOR (a:activityType)
        IDENTIFIER a.name, a.lifecycle

    // for every entry node x with eventOrigin = "Application" there is exactly one applicationPrevalenceRelation y and applicationNode z
    // with z.sysId = x.case etc
    FOR (x:entryNode) WHERE entry.eventOrigin = "Application"
    MANDATORY SINGLETON y, z WITHIN (x) - [y: applicationPrevalenceRelation] -> (z:applicationNode)
    WHERE z.sysId = x.case, z.loanGoal = x.loanGoal, z.applicationType = x.applicationType, z.requestedAmount = x.requestedAmount

    // for every entry node x with eventOrigin = "Workflow" there is exactly one workflowPrevalenceRelation y and workflowNode z
    // with z.sysId = x.case
    FOR (x:entryNode) WHERE entry.eventOrigin = "Workflow"
    MANDATORY SINGLETON y, z WITHIN (x) - [y: workflowPrevalenceRelation] -> (z:workflowNode)
    WHERE z.sysId = x.case

    // for every entry node x with eventOrigin = "Offer" AND eventId starts with "Offer_" there is exactly one offerPrevalenceRelation y and offerNode z
    // with z.sysId = x.eventId etc
    FOR (x:entryNode) WHERE entry.eventOrigin = "Offer" AND entry.eventId STARTS WITH "Offer_"
    MANDATORY SINGLETON y, z WITHIN (x) - [y: offerPrevalenceRelation] -> (z:offerNode)
    WHERE z.sysId = x.eventId, z.creditScore = x.creditScore, z.firstWithdrawalAmount = x.firstWithdrawalAmount, z.monthlyCost = x.monthlyCost, z.numberOfTerms = x.numberOfTerms, z.offeredAmount = x.offeredAmount

    // for every entry node x there is exactly one resourcePrevalenceRelation y and resourceNode z
    // with z.sysId = x.case
    FOR (x:entryNode)
    MANDATORY SINGLETON y, z WITHIN (x) - [y: resourcePrevalenceRelation] -> (z:resourceNode)
    WHERE z.sysId = x.resource

    // for every event that is prevalent in an entry should be an event type of exactly one activityNode z with z.name = entry.activity ANd z.lifecycle = entry.lifecycle
    FOR (x:eventNode) WITHIN (entry:EntryNode) <- [:eventPrevalenceRelation] - (x)
    MANDATORY SINGLETON y, z WITHIN (x) - [y:eventActivityRelation] -> (z:activityNode)
    WHERE z.name = entry.name AND z.lifecycle = entry.lifecycle

    // for every event that is prevalent in an entry with eventOrigin = "Application" should be correlated to exactly one applicationNode z with z.sysId = entry.case
    FOR (x:eventNode) WITHIN (entry:EntryNode {eventOrigin = "Application"}) <- [:eventPrevalenceRelation] - (x)
    MANDATORY SINGLETON y, z WITHIN (x) - [y:applicationCorrRelation] -> (z:applicationNode)
    WHERE z.sysId = entry.case

    // for every event that is prevalent in an entry with eventOrigin = "Workflow" should be correlated to exactly one workflowNode z with z.sysId = entry.case
    FOR (x:eventNode) WITHIN (entry:EntryNode {eventOrigin = "Workflow"}) <- [:eventPrevalenceRelation] - (x)
    MANDATORY SINGLETON y, z WITHIN (x) - [y:workflowCorrRelation] -> (z:workflowNode)
    WHERE z.sysId = entry.case

    // for every event that is prevalent in an entry with eventOrigin = "Offer" and whose eventId starts with "Offer_" should be correlated to exactly one offerNode z with z.sysId = entry.eventId
    FOR (x:eventNode) WITHIN (entry:EntryNode WHERE entry.eventOrigin = "Offer" AND entry.eventId STARTS WITHh "Offer_"}) <- [:eventPrevalenceRelation] - (x)
    MANDATORY SINGLETON y, z WITHIN (x) - [y:offerCorrRelation] -> (z:offerNode)
    WHERE z.sysId = entry.eventId

    // for every event that is prevalent in an entry with an offerId should be correlated to exactly one offerNode z with z.sysId = entry.offerId
    FOR (x:eventNode) WITHIN (entry:EntryNode WHERE entry.offerId IS NOT NULL) <- [:eventPrevalenceRelation] - (x)
    MANDATORY SINGLETON y, z WITHIN (x) - [y:offerCorrRelation] -> (z:offerNode)
    WHERE z.sysId = entry.offerId

    // for every event that is prevalent in an entry should be correlated to exactly one resourceNode z with z.sysId = entry.resource
    FOR (x:eventNode) WITHIN (entry:EntryNode) <- [:eventPrevalenceRelation] - (x)
    MANDATORY SINGLETON y, z WITHIN (x) - [y:resourceCorrRelation] -> (z:resourceNode)
    WHERE z.sysId = entry.resource

    // for every workflowNode that is prevalent in an entry node should be part of (y) exactly one applicationNode z with z.sysId = entry.case
    FOR (x:workflowNode) WITHIN (entry:EntryNode) <- [:entityPrevalenceRelation] - (x)
    MANDATORY SINGLETON y,z WITHIN (x) - [y:applicationWorkflowRelation] -> (z:applicationNode)
    WHERE z.sysId = entry.case

    // for every offerNode that is prevalent in an entry node should be an offer of (y) exactly one applicationNode z with z.sysId = entry.case
    FOR (x:offerNode) WITHIN (entry:EntryNode) <- [:entityPrevalenceRelation] - (x)
    MANDATORY SINGLETON y,z WITHIN (x) - [y:applicationOfferRelation] -> (z:applicationNode)
    WHERE z.sysId = entry.case


}

