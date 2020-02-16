#!/bin/bash
echo "Build Frontend App"
APP_NAME=frontend
mvn clean package -DskipTests=true
oc new-build --binary --name=${APP_NAME} -l app=${APP_NAME}
oc patch bc/${APP_NAME} -p "{\"spec\":{\"strategy\":{\"dockerStrategy\":{\"dockerfilePath\":\"src/main/docker/Dockerfile.jvm\"}}}}"
oc start-build ${APP_NAME} --from-dir=. --follow
oc new-app --image-stream=${APP_NAME}:latest
oc rollout pause dc ${APP_NAME}
oc set probe dc/${APP_NAME} --readiness --get-url=http://:8080/health/ready --initial-delay-seconds=15 --failure-threshold=1 --period-seconds=10
oc set probe dc/${APP_NAME} --liveness --get-url=http://:8080/health/live --initial-delay-seconds=10 --failure-threshold=3 --period-seconds=10
oc delete configmap ${APP_NAME}
oc create configmap ${APP_NAME} --from-file=config/application.properties
oc set volume dc/${APP_NAME} --add --name=${APP_NAME}-config \
--mount-path=/deployments/config/application.properties \
--sub-path=application.properties \
--configmap-name=${APP_NAME}
oc expose svc ${APP_NAME}
oc rollout resume dc ${APP_NAME}
FRONTEND_URL=$(oc get route backend -o jsonpath='{.spec.host}')
echo "Frontend: http://${FRONTEND_URL}"