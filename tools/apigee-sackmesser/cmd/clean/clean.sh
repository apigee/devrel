#
# <http://www.apache.org/licenses/LICENSE-2.0>
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

SCRIPT_FOLDER=$( (cd "$(dirname "$0")" && pwd ))
source "$SCRIPT_FOLDER/../../lib/logutils.sh"

if [ "$#" -eq 0 ]; then
    loginfo "Select at least one type to clean up. E.g.: \"clean api my-proxy\""
fi


while [ "$#" -gt 0 ]; do
  case "$1" in
    proxy) export deleteProxy="${2}"; shift 2;;
    *) logfatal "unknown option: $1" >&2; exit 1;;
  esac
done

mgmtAPIDelete() {
    loginfo "Sackmesser clean $1"
    if [ "$apiversion" = "google" ]; then
        curl -s --fail -X DELETE -H "Authorization: Bearer $token" "https://$baseuri/v1/$1"
    else
        curl -u "$username:$password" -s --fail -X DELETE "https://$baseuri/v1/$1"
    fi
}

allEnvironments=$(sackmesser list "organizations/$organization/environments" | jq -r -c '.[]|.')

if [ ! -z "$deleteProxy" ]; then
    if [ "$deleteProxy" = "all" ];then
        deleteProxy=$(sackmesser list "organizations/$organization/apis" | jq -r '.[]|.')
    fi
    for proxy in $deleteProxy; do
        for env in $allEnvironments; do
            if [ "$apiversion" = "google" ]; then
                revisionJqPattern='.deployments[] | select(.apiProxy==($API_PROXY)) | .revision'
            else
                revisionJqPattern='.aPIProxy[] | select(.name==($API_PROXY)) | .revision[] | .name'
            fi
            sackmesser list "organizations/$organization/environments/$env/deployments" | jq -r -c --arg API_PROXY "$proxy" "$revisionJqPattern" | while read -r revision; do
                mgmtAPIDelete "organizations/$organization/environments/$env/apis/$proxy/revisions/$revision/deployments"
            done
        done
    done
    mgmtAPIDelete "organizations/$organization/apis/$proxy" || logwarn "Proxy $proxy not deleted. It might not exist"
fi