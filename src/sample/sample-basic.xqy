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
            <p>{("Hello, ", <fb:name uid="{$user-id}" useyou="false" />, "!  Welcome to the basic sample app.")}</p>
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
            for $friend in $friends
            return 
                (
                    <br />, 
                    $friend, 
                    " - ", 
                    <fb:name uid="{$friend}" capitalize="true" />
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

