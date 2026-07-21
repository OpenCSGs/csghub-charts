{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{- /*
# Superset OAuth Casdoor Configuration
# Reads CASDOOR_ENDPOINT / CLIENT_ID / CLIENT_SECRET from env vars
# (pre-rendered by parent chart's secret.yaml with full context).
# Usage: {{ include "superset.oauth" . }}
*/}}
{{- define "superset.oauth" }}
import os
from flask_appbuilder.security.manager import AUTH_OAUTH
from superset.security.manager import SupersetSecurityManager

_casdoor_url = os.environ.get('CASDOOR_ENDPOINT', '')

AUTH_TYPE = AUTH_OAUTH
OAUTH_PROVIDERS = [
    {
        "name": "casdoor",
        "icon": "fa-address-card",
        "token_key": "access_token",
        "remote_app": {
            "client_id": os.environ.get('CASDOOR_CLIENT_ID', ''),
            "client_secret": os.environ.get('CASDOOR_CLIENT_SECRET', ''),
            "api_base_url": f"{_casdoor_url}/api/",
            "client_kwargs": {"scope": "openid profile email"},
            "request_token_url": None,
            "access_token_url": f"{_casdoor_url}/api/login/oauth/access_token",
            "authorize_url": f"{_casdoor_url}/login/oauth/authorize",
            "jwks_uri": f"{_casdoor_url}/.well-known/jwks",
            "userinfo": f"{_casdoor_url}/api/userinfo",
        }
    }
]


class CasdoorSecurityManager(SupersetSecurityManager):
    """Superset doesn't ship a Casdoor provider, so map the OIDC userinfo
    response to the user dict FAB expects."""

    def oauth_user_info(self, provider, response=None):
        if provider == "casdoor":
            me = self.appbuilder.sm.oauth_remotes[provider].get("userinfo")
            me.raise_for_status()
            data = me.json()
            return {
                "username": data.get("preferred_username") or data.get("name") or data.get("sub", ""),
                "email": data.get("email", ""),
                "first_name": data.get("given_name", ""),
                "last_name": data.get("family_name", ""),
            }
        return super().oauth_user_info(provider, response)


CUSTOM_SECURITY_MANAGER = CasdoorSecurityManager
AUTH_ROLE_ADMIN = 'Admin'
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = 'Admin'
{{- end -}}

{{- /*
# Superset Config Override
# Generates the full config override block (SECRET_KEY + OAuth).
# Usage: {{ include "superset.config.override" . }}
*/}}
{{- define "superset.config.override" }}
APPLICATION_ROOT = "/-/superset"
SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY')
ENABLE_PROXY_FIX = True
# Disable Talisman CSP to allow inline SVG / data:URI in browser
TALISMAN_ENABLED = False

# Override APP_ICON to a non-"/static/" path to prevent app.py from
# double-prefixing logo URLs. When APP_ICON starts with "/static/",
# app.py prepends app_root to APP_ICON and brandLogoUrl in theme tokens.
# The frontend then prepends app_root again, causing a double prefix.
APP_ICON = "/-/superset/static/assets/images/superset-logo-horiz.png"

# Enable language picker and default to Chinese
LANGUAGES = {
    "en": {"flag": "us", "name": "English"},
    "zh": {"flag": "cn", "name": "中文"},
}
BABEL_DEFAULT_LOCALE = "en"

AUTH_ROLE_PUBLIC = "Public"
PUBLIC_ROLE_LIKE = "Public"

FEATURE_FLAGS = {
    "ALERT_REPORTS": True,
    "DATASET_FOLDERS": True,
    "DASHBOARD_RBAC": True,
}

{{ include "superset.oauth" . }}
{{- end -}}

{{- /*
# Superset Bootstrap Script
# Syncs the admin password from the auto-generated env secret on every pod start.
# Usage: {{ include "superset.bootstrap" . }}
*/}}
{{- define "superset.bootstrap" }}
python3 -c "
import os
from superset import app
pwd = os.environ.get('ADMIN_PASSWORD', '')
if pwd:
    app.appbuilder.sm.reset_password('root', pwd)
" 2>/dev/null || true
{{- end -}}
