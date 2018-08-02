# Custom Script for Linux

#!/bin/bash

# The MIT License (MIT)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -ex
sleep 300

moodle_on_azure_configs_json_path=${1}

. ./helper_functions.sh

get_setup_params_from_configs_json $moodle_on_azure_configs_json_path || exit 99

echo $siteFQDN >> /tmp/vars.txt
echo $lbdns >> /tmp/vars.txt
echo $wafpasswd >> /tmp/vars.txt
echo $waflbdns >> /tmp/vars.txt

# Check for the WAF availability

# Login Token
login_token = `curl -X POST "http://<WAF-IP/WAF-Domain>:8000/restapi/v3/login " \
-H "accept: application/json" -d '{"username":"admin","password":""$wafpasswd""}'`

# Creating the certificate
{
curl -X POST "http://$waflbdns:8000/restapi/v3/certificates " \
-H "accept: application/json" -u "test:" \
-H "Content-Type: application/json" \
-d '{ "allow_private_key_export": "Yes", "city": "San Franscisco", "common_name": ""$siteFQDN"", "country_code": "US", "curve_type": "secp256r1", "key_size": "2048", "key_type": "rsa", "name": "moodle_cert", "organization_name": "Moodle", "organization_unit": "MoodleTeam", "state": "CA"}'
}
# Creating the service
{
curl -X POST "http://$waflbdns:8000/restapi/v3/services " \
-H "accept: application/json" -u ""$login_token":" -H "Content-Type: application/json" \
-d '{ "address-version": "IPv4", "app-id": "moodle", "certificate": "moodle_cert", "group": "default", "ip-address": "string", "mask": "string", "name": "moodle_service", "port": 443, "status": "On", "type": "HTTPS", "vsite": "default"}'
}
# Creating the server
{
curl -X POST "http://$waflbdns:8000/restapi/v3/services/moodle_service/servers " \
-H "accept: application/json" -u ""$login_token":" -H "Content-Type: application/json" \
-d '{ "hostname": "$lbdns", "status": "In Service", "identifier": "Hostname", "address-version": "IPv4", "name": "moodle_server", "port": 443}'
}
# Enabling SSL on the server
{
curl -X PUT "http://$waflbdns:8000/restapi/v3/services/moodle_service/servers/moodle_server/ssl-policy " \
-H "accept: application/json" -u ""$login_token":" -H "Content-Type: application/json" \
-d '{ "enable-ssl-compatibility-mode": "No", "enable-https": "Yes", "enable-tls-1": "No", "enable-tls-1-2": "Yes", "enable-ssl-3": "No", "enable-sni": "No", "validate-certificate": "No", "enable-tls-1-1": "Yes", "client-certificate": ""}'
}