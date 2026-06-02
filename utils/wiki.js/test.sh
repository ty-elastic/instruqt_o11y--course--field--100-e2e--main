
get_jwt() {
   printf "$FUNCNAME...\n"
   # Define the raw GraphQL query text
   gql_query='
   mutation ($username: String!, $password: String!, $strategy: String!) {
      authentication {
         login(username: $username, password: $password, strategy: $strategy) {
            responseResult {
               succeeded
               errorCode
               slug
               message
               __typename
            }
            jwt
            mustChangePwd
            mustProvideTFA
            mustSetupTFA
            continuationToken
            redirect
            tfaQRImage
            __typename
         }
         __typename
      }
   }'

   # Define variables as a JSON string
   gql_variables='{"username":"admin@example.com","password":"password123","strategy":"local"}'

   body="$(jq -n --arg q "$gql_query" --argjson v "$gql_variables" '{query: $q, variables: $v}')"
   echo $body

   output=$(curl -s -X POST "http://$SERVICE_IP:$SERVICE_PORT/graphql" \
         -w "\n%{http_code}" \
         -H 'Content-Type: application/json' \
         -d "$body")

   # Extract HTTP status code
   http_code=$(echo "$output" | tail -n1)
   http_response=$(echo "$output" | sed '$d')
   if [ "$http_code" != "200" ]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi

   JWT=$(echo $http_response | jq -r '.data.authentication.login.jwt')

   printf "$FUNCNAME...JWT=$JWT\n"
   return 0
}
get_jwt

add_content() {
   printf "$FUNCNAME...\n"
   # Define the raw GraphQL query text
   gql_query='
    mutation {
        pages {
            create(
                title: "API markdown test page"
                content:"# Header\n\n```js\nconst x = 5;\n```"
                description: "Page made through API"
                editor: "markdown"
                isPublished:true
                isPrivate: false
                locale: "en"
                path: "/api-markdown-test-page"
                tags:[ "api", "test"]
            ) {
                responseResult {
                    succeeded
                    errorCode
                    message
                }
                page {
                    id
                    path
                    contentType
                }
            }
        }
    }'

   # Define variables as a JSON string
   gql_variables='{"username":"admin@example.com","password":"password123","strategy":"local"}'

   body="$(jq -n --arg q "$gql_query" --argjson v "$gql_variables" '{query: $q}')"
   #echo $body

   output=$(curl -s -X POST "http://$SERVICE_IP:$SERVICE_PORT/graphql" \
         -w "\n%{http_code}" \
         -H "Authorization: Bearer $JWT" \
         -H 'Content-Type: application/json' \
         -d "$body")

   # Extract HTTP status code
   http_code=$(echo "$output" | tail -n1)
   http_response=$(echo "$output" | sed '$d')
   if [ "$http_code" != "200" ]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi

   printf "$FUNCNAME...SUCCESS\n"
   return 0
}
add_content




#[{"operationName":null,"variables":{"enabled":true},"extensions":{},"query":"mutation ($enabled: Boolean!) {\n  authentication {\n    setApiState(enabled: $enabled) {\n      responseResult {\n        succeeded\n        errorCode\n        slug\n        message\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n}\n"}]