xquery version "0.9-ml"

(:
:: Copyright 2002-2008 Mark Logic Corporation.  All Rights Reserved. 
:: This software is licensed to you under the terms and conditions
:: specified at http://www.apache.org/licenses/LICENSE-2.0. If you
:: do not agree to those terms and conditions, you must cease use of
:: and destroy any copies of this software that you have downloaded. 
:)

module "http://marklogic.com/xdmp/facebook"

declare namespace mlfb="http://marklogic.com/xdmp/facebook"
declare namespace fb="http://api.facebook.com/1.0/"
declare namespace qm = "http://marklogic.com/xdmp/query-meters"

define variable $mlfb:null as xs:string { "null" }

define function mlfb:get-lib-version()
{
    "version 1.0.0"
}

define function mlfb:facebook-create-config(
    $api-key as xs:string, 
    $secret as xs:string
) as element(mlfb:facebook-config)
{
    mlfb:validate-fb-params(
        <mlfb:facebook-config>
            <mlfb:api-key>{$api-key}</mlfb:api-key>
            <mlfb:secret-key>{$secret}</mlfb:secret-key>
        </mlfb:facebook-config>
    )
}

define function mlfb:get-api-key(
    $facebook as element(mlfb:facebook-config)
) as xs:string
{
    $facebook/mlfb:api-key/text()
}

define function mlfb:get-secret-key(
    $facebook as element(mlfb:facebook-config)
) as xs:string
{
    $facebook/mlfb:secret-key/text()
}

define function mlfb:get-user(
    $facebook as element(mlfb:facebook-config)
) as xs:string?
{
    $facebook/mlfb:user/text()
}

define function mlfb:get-session-key(
    $facebook as element(mlfb:facebook-config)
) as xs:string?
{
    $facebook/mlfb:session-key/text()
}

define function mlfb:get-fb-params(
    $facebook as element(mlfb:facebook-config)
) as element(mlfb:fb-param)*
{
    $facebook/mlfb:fb-params/*
}

define function mlfb:get-fb-param-value(
    $facebook as element(mlfb:facebook-config),
    $param-name as xs:string
) as xs:string?
{
    $facebook/mlfb:fb-params/mlfb:fb-param[mlfb:name = $param-name]/mlfb:value/text()
}

define function mlfb:redirect-login(
    $facebook as element(mlfb:facebook-config)
) as xs:string?
{
    mlfb:redirect($facebook, mlfb:get-login-url($facebook, mlfb:current-url()))
}

define function mlfb:redirect-add(
    $facebook as element(mlfb:facebook-config)
) as xs:string?
{
    mlfb:redirect($facebook, mlfb:get-add-url($facebook))
}

define function mlfb:redirect(
    $facebook as element(mlfb:facebook-config),
    $url as xs:string
) as xs:string?
{
    if (mlfb:get-fb-param-value($facebook, "in_canvas"))
    then
        fn:concat('<fb:redirect url="', $url, '"/>')
    else
        xdmp:redirect-response($url)
}

define function mlfb:get-login-url(
    $facebook as element(mlfb:facebook-config),
    $next as xs:string
) as xs:string
{
    fn:concat(
        mlfb:get-facebook-url(), 
        '/login.php?v=1.0&api_key=', 
        mlfb:get-api-key($facebook), 
        if ($next)
        then fn:concat('&next=', fn:encode-for-uri($next))
        else ()
    )
}

define function mlfb:get-add-url(
    $facebook as element(mlfb:facebook-config)
) as xs:string
{
    fn:concat(mlfb:get-facebook-url(), '/add.php?api_key=', mlfb:get-api-key($facebook))
}

define function mlfb:get-facebook-url(
) as xs:string
{
    'http://www.facebook.com'
}

define function mlfb:current-url(
) as xs:string
{
    fn:concat("http://", xdmp:get-request-header("Host"), xdmp:get-request-path())
}

define function mlfb:validate-fb-params(
    $facebook as element(mlfb:facebook-config)
) as element(mlfb:facebook-config)
{
    let $facebook := mlfb:get-valid-fb-params($facebook, xdmp:get-request-field-names())
    return 
        if (mlfb:get-fb-params($facebook))
        then
        (
            let $facebook := mlfb:add-config-element($facebook, <mlfb:user>{mlfb:get-fb-param-value($facebook, "user")}</mlfb:user>)
            return mlfb:add-config-element($facebook, <mlfb:session-key>{mlfb:get-fb-param-value($facebook, "session_key")}</mlfb:session-key>)
        )
        else
            if (xdmp:get-request-field-names() = "auth_token")
            then mlfb:auth-get-session($facebook, xdmp:get-request-field("auth_token"))
            else $facebook
}

define function mlfb:get-valid-fb-params(
    $facebook as element(mlfb:facebook-config), 
    $params as xs:string*
) as element(mlfb:facebook-config)
{
    let $prefix := "fb_sig_"
    let $prefix-length := fn:string-length($prefix)
    let $fb-params :=
    <mlfb:fb-params>
    {
        for $param in $params
        let $val := xdmp:get-request-field($param)
        return
            if (fn:starts-with($param, $prefix))
            then
            <mlfb:fb-param>
                <mlfb:name>{fn:substring($param, $prefix-length + 1)}</mlfb:name>
                <mlfb:value>{$val}</mlfb:value>
             </mlfb:fb-param>
            else ()
    }
    </mlfb:fb-params>
    return mlfb:add-config-element($facebook, $fb-params)
}

define function mlfb:add-config-element(
    $facebook as element(mlfb:facebook-config), 
    $node as node()
) as element(mlfb:facebook-config)
{
    <mlfb:facebook-config>
    {
    (
        for $config-element in $facebook/*
        return
            if (fn:node-name($node) = fn:node-name($config-element))
            then ()
            else $config-element
        ,
        $node
    )
    }
    </mlfb:facebook-config>
}



















(: REST Client Library Function :)




define function mlfb:get-call-id(
) as xs:string
{
    let
    $ts-orig := xs:string(fn:current-dateTime() + xdmp:query-meters()/qm:elapsed-time),
    $ts-no-tz := fn:string-join(fn:tokenize($ts-orig, "-")[1 to fn:last()-1], ""),
    $ts-no-tz-length := fn:string-length($ts-no-tz),
    $ts-dif := 24 - $ts-no-tz-length,
    $zeros :=
    (
    if ($ts-dif = 0)
    then ""
    else
    fn:string-join(
      (
      let $zero-list := 1 to $ts-dif
      for $z in $zero-list
      return
      "0"
      ),
    "")
    ),
    $ts-raw := fn:concat($ts-no-tz, $zeros),
    $ts-clean := fn:replace($ts-raw, "[^0-9]", "")
    return
    $ts-clean
}


define function mlfb:http-post-server-address(
) as xs:string
{
    "http://api.facebook.com/restserver.php"
}


define function mlfb:null-for-auth(
    $method as xs:string,
    $item as xs:string?
) as xs:string?
{
    if ($method = "facebook.auth.getSession")
    then $mlfb:null
    else $item
}

(: change 'null' to something more obscure :)
define function mlfb:post-gen-string(
    $facebook as element(mlfb:facebook-config), 
    $method as xs:string, 
    $field-names as xs:string*, 
    $field-values as xs:string*
) as xs:string
{
    let 
    $api-key := mlfb:get-api-key($facebook),
    $secret-key := mlfb:get-secret-key($facebook),
    $session-key := mlfb:null-for-auth($method, mlfb:get-session-key($facebook)),
    $call-id := mlfb:null-for-auth($method, mlfb:get-call-id()),
    $version := "1.0",
    $unordered-names := (("api_key", "call_id", "method", "session_key", "v"), $field-names),
    $param-names :=
        for $rand-name in $unordered-names
        order by $rand-name
        return $rand-name,
    $unordered-values := (($api-key, $call-id, $method, $session-key, $version), $field-values),
    $param-values :=
        for $p-name in $param-names
        let $p-indices := fn:index-of($unordered-names, $p-name)
        let $p-index := $p-indices[1]
        let $p-value := $unordered-values[$p-index]
        return $p-value,
    $param-names-count := xdmp:log(fn:string-join($param-names, "***")),
    $param-values-count := xdmp:log(fn:string-join($param-values, "***")),
    $sig-string :=
        fn:concat(
        fn:string-join(
        (
        for $p-name at $pos in $param-names
        let $p-value := xs:string($param-values[$pos])
        return
          if (fn:not($p-value = $mlfb:null))
          then
            fn:concat($p-name, "=", $p-value)
          else ()
        ),
        ""),
        $secret-key),
    $sig-value := xdmp:md5($sig-string)
    return
        fn:concat(
        fn:string-join(
        (
        for $p-name at $pos in $param-names
        let $p-value := xs:string($param-values[$pos])
        return
          if (fn:not($p-value = $mlfb:null))
          then
            fn:concat(
              if ($pos = 1)
              then ()
              else "&",
              $p-name,
              "=",
              $p-value
            )
          else ()
        ),
        ""),
        fn:concat("&sig=", $sig-value))
}




(: have 'else' do final attempt without try-catch :)
define function mlfb:post-method-attempt(
    $post-string as xs:string, 
    $trials as xs:unsignedLong
) as item()+
{
        if ($trials gt 0)
        then
        try {
            (
            xdmp:log(fn:concat("http post successful with trials left ", $trials, " - ", $post-string)),
                xdmp:http-post(mlfb:http-post-server-address(),
                        <options xmlns="xdmp:http">
                                <headers>
                                        <content-type>application/x-www-form-urlencoded</content-type>
                                </headers>
                                <data>{$post-string}</data>
                        </options>
                )
            )
        } catch ($e) {
            (
                xdmp:log(fn:concat("Trial Failed, trials left: ", $trials)),
                xdmp:log($e),
                xdmp:sleep(50),
                let $new-trials := $trials - 1
                return
                    mlfb:post-method-attempt($post-string, $new-trials)
            )
        }
        else
        (
                xdmp:log(fn:concat("Attempted max number of trials for http post: ", $post-string)),
                fn:error()
        )
}

(: get rid of this try-catch :)
define function mlfb:post-method(
    $facebook as element(mlfb:facebook-config), 
    $method as xs:string, 
    $field-names as xs:string*, 
    $field-values as xs:string*
) as item()+
{
    let
        $trials-total := 5,
        $post-string := mlfb:post-gen-string($facebook, $method, $field-names, $field-values)
    let $result-of-post :=
        try {
                mlfb:post-method-attempt($post-string, $trials-total)
        } catch ($e) {
        (
                xdmp:log($e),
                xdmp:log("Completed max number of trials for HTTP POST.")
                (: redirect to error page :)
        )
        }



     return
        if ($result-of-post)
        then
                if (fn:count($result-of-post) lt 2)
                then
                        fn:error("FACEBOOK-INVALID-HTTP-RESPONSE", $result-of-post)
                else if ($result-of-post[2]/fb:error_response)
                then
                        fn:error("FACEBOOK-API-ERROR-RESPONSE", $result-of-post)
                else
                    (xdmp:log(xdmp:quote($result-of-post[2])),
                        $result-of-post[2]
                    )
        else
                fn:error(fn:error("FACEBOOK-NO-HTTP-RESPONSE"))

}





define function mlfb:get-logged-in-user(
    $facebook as element(mlfb:facebook-config)
) as xs:string
{
    let $post-result := mlfb:post-method($facebook, "facebook.users.getLoggedInUser", (), ())
    return $post-result/fb:users_getLoggedInUser_response/text()
}


define function mlfb:auth-get-session(
    $facebook as element(mlfb:facebook-config), 
    $auth-token as xs:string
) as element(mlfb:facebook-config)
{
    let $post-result := mlfb:post-method($facebook, "facebook.auth.getSession", ("auth_token"), ($auth-token))
    let $session-key := $post-result/fb:auth_getSession_response/fb:session_key/text()
    let $facebook := mlfb:add-config-element($facebook, <mlfb:session-key>{$session-key}</mlfb:session-key>)
    let $user-id := $post-result/fb:auth_getSession_response/fb:uid/text()
    let $facebook := mlfb:add-config-element($facebook, <mlfb:user>{$user-id}</mlfb:user>)
    let $expires := $post-result/fb:auth_getSession_response/fb:expires/text()
    return mlfb:add-config-element($facebook, <mlfb:expires>{$expires}</mlfb:expires>)
}

define function mlfb:is-app-added(
    $facebook as element(mlfb:facebook-config)
) as xs:boolean
{
    let $post-result := mlfb:post-method($facebook, "facebook.users.isAppAdded", (), ())
    let $result-string := $post-result/fb:users_isAppAdded_response/text()
    return $result-string = "1"
}

define function mlfb:friends-get(
    $facebook as element(mlfb:facebook-config)
) as node()
{
    mlfb:post-method($facebook, "facebook.friends.get", (), ())
}


define function mlfb:profile-set-fbml(
    $facebook as element(mlfb:facebook-config), 
    $uid as xs:string, 
    $markup as xs:string,
	$profile as xs:string,
	$profile-action as xs:string,
	$mobile-profile as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.profile.setFBML", 
        ("uid", "markup", "profile", "profile_action", "mobile_profile"), 
        ($uid, $markup, $profile, $profile-action, $mobile-profile)
    )
}


define function mlfb:events-get(
    $facebook as element(mlfb:facebook-config), 
    $uid as xs:string, 
    $eids as xs:string,
	$start-time as xs:string,
	$end-time as xs:string,
	$rsvp-status as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.events.get", 
        ("uid", "eids", "start_time", "end_time", "rsvp_status"), 
        ($uid, $eids, $start-time, $end-time, $rsvp-status)
    )
}


define function mlfb:events-get-members(
    $facebook as element(mlfb:facebook-config), 
    $eid as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.events.getMembers", 
        ("eid"), 
        ($eid)
    )
}

define function mlfb:fbml-refresh-img-src(
    $facebook as element(mlfb:facebook-config), 
    $url as xs:string 
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.fbml.refreshImgSrc", 
        ("url"), 
        ($url)
    )
}

define function mlfb:fbml-refresh-ref-url(
    $facebook as element(mlfb:facebook-config), 
    $url as xs:string 
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.fbml.refreshRefUrl", 
        ("url"), 
        ($url)
    )
}

define function mlfb:fbml-set-ref-handle(
    $facebook as element(mlfb:facebook-config), 
    $handle as xs:string, 
    $fbml as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.fbml.setRefHandle", 
        ("handle", "fbml"), 
        ($handle, $fbml)
    )
}


define function mlfb:feed-publish-story-to-user(
     $facebook as element(mlfb:facebook-config), 
     $title as xs:string,
     $body as xs:string,
     $image_1 as xs:string,
     $image_1_link as xs:string,
     $image_2 as xs:string,
     $image_2_link as xs:string,
     $image_3 as xs:string,
     $image_3_link as xs:string,
     $image_4 as xs:string,
     $image_4_link as xs:string,
     $priority as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.feed.publishStoryToUser", 
        ("title", "body", "image_1", "image_1_link", "image_2", "image_2_link", "image_3", "image_3_link", "image_4", "image_4_link", "priority"),
        ($title, $body, $image_1, $image_1_link, $image_2, $image_2_link, $image_3, $image_3_link, $image_4, $image_4_link, $priority)
    )
}


define function mlfb:feed-publish-action-of-user(
     $facebook as element(mlfb:facebook-config), 
     $title as xs:string,
     $body as xs:string,
     $image_1 as xs:string,
     $image_1_link as xs:string,
     $image_2 as xs:string,
     $image_2_link as xs:string,
     $image_3 as xs:string,
     $image_3_link as xs:string,
     $image_4 as xs:string,
     $image_4_link as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.feed.publishActionOfUser", 
        ("title", "body", "image_1", "image_1_link", "image_2", "image_2_link", "image_3", "image_3_link", "image_4", "image_4_link"),
        ($title, $body, $image_1, $image_1_link, $image_2, $image_2_link, $image_3, $image_3_link, $image_4, $image_4_link)
    )
}


define function mlfb:feed-publish-templatized-action(
     $facebook as element(mlfb:facebook-config), 
     $title-template as xs:string,
     $title-data as xs:string,
     $body-template as xs:string,
     $body-data as xs:string,
     $body-general as xs:string,
     $page-actor-id as xs:string,
     $image_1 as xs:string,
     $image_1_link as xs:string,
     $image_2 as xs:string,
     $image_2_link as xs:string,
     $image_3 as xs:string,
     $image_3_link as xs:string,
     $image_4 as xs:string,
     $image_4_link as xs:string,
     $target-ids as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.feed.publishTemplatizedAction", 
        ("title_template", "title_data", "body_template", "body_data", "body_general", "page_actor_id", "image_1", "image_1_link", "image_2", "image_2_link", "image_3", "image_3_link", "image_4", "image_4_link", "target_ids"),
        ($title-template, $title-data, $body-template, $body-data, $body-general, $page-actor-id, $image_1, $image_1_link, $image_2, $image_2_link, $image_3, $image_3_link, $image_4, $image_4_link, $target-ids)
    )
}

define function mlfb:fql-query(
    $facebook as element(mlfb:facebook-config), 
    $query as xs:string 
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.fql.query", 
        ("query"), 
        ($query)
    )
}

define function mlfb:friends-are-friends(
    $facebook as element(mlfb:facebook-config), 
    $uids-one as xs:string, 
    $uids-two as xs:string 
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.friends.areFriends", 
        ("uids1", "uids2"), 
        ($uids-one, $uids-two)
    )
}

define function mlfb:friends-get-app-users(
    $facebook as element(mlfb:facebook-config)
) as node()
{
    mlfb:post-method($facebook, "facebook.friends.getAppUsers", (), ())
}


define function mlfb:groups-get(
    $facebook as element(mlfb:facebook-config),
    $uid as xs:string,
    $gids as xs:string
) as node()
{
    mlfb:post-method($facebook, "facebook.groups.get", ("uid", "gids"), ($uid, $gids))
}

define function mlfb:groups-get-members(
    $facebook as element(mlfb:facebook-config),
    $gid as xs:string
) as node()
{
    mlfb:post-method($facebook, "facebook.groups.getMembers", ("gid"), ($gid))
}


define function mlfb:notifications-get(
    $facebook as element(mlfb:facebook-config)
) as node()
{
    mlfb:post-method($facebook, "facebook.notifications.get", (), ())
}

define function mlfb:notifications-send(
    $facebook as element(mlfb:facebook-config),
    $to-ids as xs:string,
    $notification as xs:string
) as node()
{
    mlfb:post-method($facebook, "facebook.notifications.send", ("to_ids", "notification"), ($to-ids, $notification))
}

define function mlfb:notifications-send-email(
    $facebook as element(mlfb:facebook-config),
    $recipients as xs:string,
    $subject as xs:string,
    $text as xs:string,
    $fbml as xs:string
) as node()
{
    mlfb:post-method($facebook, "facebook.notifications.sendEmail", ("recipients", "subject", "text", "fbml"), ($recipients, $subject, $text, $fbml))
}

define function mlfb:photos-add-tag(
    $facebook as element(mlfb:facebook-config),
    $pid as xs:string,
    $tag-uid as xs:string,
    $tag-text as xs:string,
    $x as xs:string,
    $y as xs:string,
    $tags as xs:string,
    $owner-uid as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.photos.addTag", 
        ("pid", "tag_uid", "tag_text", "x", "y", "tags", "owner_uid"), 
        ($pid, $tag-uid, $tag-text, $x, $y, $tags, $owner-uid)
    )
}


define function mlfb:photos-create-album(
    $facebook as element(mlfb:facebook-config),
    $name as xs:string,
    $location as xs:string,
    $description as xs:string,
    $uid as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.photos.createAlbum", 
        ("name", "location", "description", "uid"), 
        ($name, $location, $description, $uid)
    )
}


define function mlfb:photos-get(
    $facebook as element(mlfb:facebook-config),
    $subj-id as xs:string,
    $aid as xs:string,
    $pids as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.photos.get", 
        ("subj_id", "aid", "pids"), 
        ($subj-id, $aid, $pids)
    )
}

define function mlfb:photos-get-albums(
    $facebook as element(mlfb:facebook-config),
    $uid as xs:string,
    $aids as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.photos.getAlbums", 
        ("uid", "aids"), 
        ($uid, $aids)
    )
}

define function mlfb:photos-get-tags(
    $facebook as element(mlfb:facebook-config),
    $pids as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.photos.getTags", 
        ("pids"), 
        ($pids)
    )
}

define function mlfb:profile-get-fbml(
    $facebook as element(mlfb:facebook-config),
    $uid as xs:string,
    $type as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.profile.getFBML", 
        ("uid", "type"), 
        ($uid, $type)
    )
}

define function mlfb:users-get-info(
    $facebook as element(mlfb:facebook-config),
    $uids as xs:string,
    $fields as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.users.getInfo", 
        ("uids", "fields"), 
        ($uids, $fields)
    )
}

define function mlfb:users-has-app-permission(
    $facebook as element(mlfb:facebook-config),
    $ext-perm as xs:string,
    $uid as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.users.hasAppPermission", 
        ("ext_perm", "uid"), 
        ($ext-perm, $uid)
    )
}

define function mlfb:users-set-status(
    $facebook as element(mlfb:facebook-config),
    $status as xs:string,
    $clear as xs:string,
    $status-includes-verb as xs:string,
    $uid as xs:string
) as node()
{
    mlfb:post-method(
        $facebook, 
        "facebook.users.setStatus", 
        ("status", "clear", "status_includes_verb", "uid"), 
        ($status, $clear, $status-includes-verb, $uid)
    )
}













