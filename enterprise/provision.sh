docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms --settings=devstack_docker manage_user enterprise_worker enterprise_worker@example.com --staff'
cat enterprise/worker_permissions.py | docker-compose $DOCKER_COMPOSE_FILES exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms shell  --settings=devstack_docker'
