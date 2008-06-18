xquery version "0.9-ml"

(: HELLO WORLD - FACEBOOK :)

import module namespace mlfb="http://marklogic.com/xdmp/facebook" at "/facebook/facebook.xqy"

declare namespace fb="http://api.facebook.com/1.0/"

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
        (
            <p>{("Hello, ", <fb:name uid="{$user-id}" useyou="false" />, "!")}</p>
            ,
            <p>
            {
            (
                "Friends:"
                ,
                let $friends := mlfb:friends-get($facebook)/fb:friends_get_response/fb:uid/text()
                let $friends := $friends[1 to 25]
                for $friend in $friends
                return (<br />, $friend)
            )
            }
            </p>
       )
)


(:

<?php
// Copyright 2007 Facebook Corp.  All Rights Reserved. 
// 
// Application: Test Xqy
// File: 'index.php' 
//   This is a sample skeleton for your application. 
// 

require_once 'facebook.php';

$appapikey = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
$appsecret = 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy';
$facebook = new Facebook($appapikey, $appsecret);
$user_id = $facebook->require_login();

// Greet the currently logged-in user!
echo "<p>Hello, <fb:name uid=\"$user_id\" useyou=\"false\" />!</p>";

// Print out at most 25 of the logged-in user's friends,
// using the friends.get API method
echo "<p>Friends:";
$friends = $facebook->api_client->friends_get();
$friends = array_slice($friends, 0, 25);
foreach ($friends as $friend) {
  echo "<br>$friend";
}
echo "</p>";

:)














(:
//PHP equivalent

require_once 'facebook.php';

$appapikey := 'bfc4dbecbce10d6492fb622ed6f3a7e6'
$appsecret := 'a6e6201d2d6411d967fc3425be672xx'

$facebook = new Facebook($appapikey, $appsecret);
$user_id = $facebook->require_login();
try {
 if (!$facebook->api_client->users_isAppAdded()) {
   $facebook->redirect($facebook->get_add_url());
 }
} catch (Exception $ex) {
 //this will clear cookies for your application and redirect them to a login prompt
 $facebook->set_user(null, null);
 $facebook->redirect($SITE_URL);
}


// Greet the currently logged-in user!
echo "<p>Hello, <fb:name uid=\"$user_id\" useyou=\"false\" />!</p>";

// Print out at most 25 of the logged-in user's friends,
// using the friends.get API method
echo "<p>Friends:";
$friends = $facebook->api_client->friends_get();
$friends = array_slice($friends, 0, 25);
foreach ($friends as $friend) {
  echo "<br>$friend";
}
echo "</p>";

:)

