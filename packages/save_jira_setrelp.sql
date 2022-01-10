DECLARE
    e_error              EXCEPTION;
    l_base_url           VARCHAR2 (1000)
        := 'https://jira.oraclecorp.com/jira/rest/api/latest/issue';

    l_param_names        apex_application_global.vc_arr2;
    l_param_vals         apex_application_global.vc_arr2;
    l_error_message      ax_errors.error_message%TYPE;

    l_response           CLOB;
    l_test varchar2(1000);
    l_body               blob;    
    CURSOR c_get_version
    IS
        SELECT version
          FROM apex_applications
         WHERE application_id = :app_id;

    l_version            apex_applications.version%TYPE;
    l_wallet_path        ax_sysprm.sys_conf_value%TYPE;
    l_wallet_pwd         ax_sysprm.sys_conf_value%TYPE;
    l_generic_username   ax_sysprm.sys_conf_value%TYPE;
    l_generic_pwd        ax_sysprm.sys_conf_value%TYPE;
BEGIN
  — test
    OPEN c_get_version;

    FETCH c_get_version INTO l_version;

    CLOSE c_get_version;

    IF NOT ax_utility_sql.get_sysprm (
               o_error_message    => o_error_message,
               o_sys_conf_value   => l_wallet_path,
               i_sys_conf_name    => 'JIRA_WALLET_PATH')
    THEN
        RAISE e_error;
    END IF;

    IF NOT ax_utility_sql.get_sysprm (o_error_message    => o_error_message,
                                      o_sys_conf_value   => l_wallet_pwd,
                                      i_sys_conf_name    => 'JIRA_WALLET_PWD')
    THEN
        RAISE e_error;
    END IF;

    IF NOT ax_utility_sql.get_sysprm (
               o_error_message    => o_error_message,
               o_sys_conf_value   => l_generic_username,
               i_sys_conf_name    => 'JIRA_GENERIC_USERNAME')
    THEN
        RAISE e_error;
    END IF;

    IF NOT ax_utility_sql.get_sysprm (
               o_error_message    => o_error_message,
               o_sys_conf_value   => l_generic_pwd,
               i_sys_conf_name    => 'JIRA_GENERIC_PWD')
    THEN
        RAISE e_error;
    END IF;

    l_body :=
           '{
    "fields": {
       "project":
       {
          "key": "SETRELP"
       },
       "summary": "'
        || :p2_summary
        || '",
       "description": "'
        || REPLACE (REPLACE (:p2_description, CHR (10), '\n'),
                    CHR (13),
                    '\n')
        || '",
       "reporter":{"name":"'
        || :app_user
        || '"},
       "assignee":{"name":"deirdre.matishak@oracle.com"},
       "priority":{"name":"None"},
       "labels":[
         "Intelligence"
      ],
      "versions":[
         {
            "name":"'
        || l_version
        || '"
         }
      ],
       "issuetype": {
          "name": "Story"          
       }
   }
}'   ;

    apex_web_service.g_request_headers.delete ();
    apex_web_service.g_request_headers (1).name := 'Content-Type';
    apex_web_service.g_request_headers (1).VALUE := 'application/json';
    apex_web_service.g_request_headers (2).name := 'Accept';
    apex_web_service.g_request_headers (2).VALUE := 'application/json';

    l_response :=
        apex_web_service.make_rest_request (
            p_url           => l_base_url,
            p_http_method   => 'POST',
            p_wallet_path   => l_wallet_path,
            p_wallet_pwd    => l_wallet_pwd,
            p_username      => l_generic_username,
            p_password      => l_generic_pwd,
            p_body          => l_body,
            p_parm_name     => l_param_names,
            p_parm_value    => l_param_vals);

    IF (   apex_web_service.g_status_code = UTL_HTTP.http_ok
        OR apex_web_service.g_status_code = UTL_HTTP.http_created)
    THEN
        apex_json.parse (l_response);
        :p2_jira_id := apex_json.get_varchar2 ('key');
    ELSE
        l_error_message := apex_web_service.g_status_code || l_response;
        RAISE e_error;
    END IF;
EXCEPTION
    WHEN e_error
    THEN
        raise_application_error (-20001, l_error_message);
    WHEN OTHERS
    THEN
        raise_application_error (-20001, ax_utility_sql.get_oracle_error);
END;