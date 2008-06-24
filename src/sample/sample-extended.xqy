xquery version "0.9-ml"

import module namespace mlfb="http://marklogic.com/xdmp/facebook" at "/facebook/facebook.xqy"

declare namespace fb="http://api.facebook.com/1.0/"

try {
let $app-api-key := 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
let $app-secret := 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy'

let $facebook := mlfb:facebook-create-config($app-api-key, $app-secret)
let $user-id := mlfb:get-user($facebook)
return
(
    if (fn:empty($user-id))
    then 
        mlfb:redirect-login($facebook)
    else
        let $is-app-added := mlfb:is-app-added($facebook)
        return
        if (fn:not($is-app-added))
        then
            mlfb:redirect-add($facebook)
        else
        (
            <p>{("Hello, ", <fb:name uid="{$user-id}" useyou="false" />, "!  Welcome to the extended sample app.")}</p>
            ,
            <br />
            ,
            let $events := mlfb:events-get($facebook, $mlfb:null, $mlfb:null, $mlfb:null, $mlfb:null, $mlfb:null)/fb:events_get_response/fb:event
            for $event in $events
            let $event-name := $event/fb:name/text()
            let $event-id := $event/fb:eid/text()
            let $attendees := mlfb:events-get-members($facebook, $event-id)/fb:events_getMembers_response/fb:attending/fb:uid/text()
            return 
            <p>
            {
            (
                fn:concat("Event (", $event-id, "): ", $event-name)
                ,
                <br />
                ,
                "Some of the attendees: "
                ,
                <br />
                ,
                for $attendee in $attendees[1 to 10]
                return ("-", <fb:name uid="{$attendee}" useyou="false" linked="false" />, <br />)
            )
            }
            </p>
            ,
            <br />
            ,
            "Friends: "
            ,
            let $friends := mlfb:friends-get($facebook)/fb:friends_get_response/fb:uid/text()
            let $set-fmbl := mlfb:profile-set-fbml(
                $facebook, 
                $mlfb:null, 
                $mlfb:null, 
                xdmp:quote(<i>{fn:concat("Friend Count: ", fn:count($friends))}</i>), 
                $mlfb:null, 
                $mlfb:null
            )
            let $friends := $friends[1 to 25]
            let $friends-info := mlfb:users-get-info($facebook, fn:string-join($friends, ","), "current_location,political")
            for $friend in $friends
            let $current-city := $friends-info/fb:users_getInfo_response/fb:user[fb:uid = $friend]/fb:current_location/fb:city/text()
            let $political := $friends-info/fb:users_getInfo_response/fb:user[fb:uid = $friend]/fb:political/text()
            return 
                (
                    <br />, 
                    $friend, 
                    " - ", 
                    <fb:name uid="{$friend}" capitalize="true" />, 
                    if ($current-city) then (" - Lives in ", $current-city) else (),
                    if ($political) then (" - Is politically ", $political) else ()
                )
            ,
            mlfb:feed-publish-action-of-user(
                $facebook,
                "performed a test action.",
                "More content about the test action",
                "http://www.crunchbase.com/assets/images/resized/0000/4552/4552v2-max-138x333.jpg",
                "http://www.facebook.com",
                $mlfb:null,
                $mlfb:null,
                $mlfb:null,
                $mlfb:null,
                $mlfb:null,
                $mlfb:null
            )
        )
)
}
catch ($e) {
(
    <p>Sorry, an error occured on this page.</p>
    ,
    xdmp:log($e)
)
}

