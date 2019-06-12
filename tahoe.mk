DEVSTACK_WORKSPACE ?= ..

tahoe.exec.single:  ## Execute a command inside a devstack docker container
	docker exec -t edx.devstack.$(SERVICE)  \
		bash -c 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform/ && $(COMMAND)'

tahoe.exec.edxapp:   ## Execute a command in both LMS and Studio (edxapp containers)
	make COMMAND='$(COMMAND)' SERVICE=lms tahoe.exec.single
	make COMMAND='$(COMMAND)' SERVICE=studio tahoe.exec.single

tahoe.chown:  ## Fix annoying docker permission issues
	sudo chown -R $(USER) $(DEVSTACK_WORKSPACE)

tahoe.theme.hack:  ## Link the customer theme in a pretty hacky way, sorry I don't know a better way
	sudo rm -f $(DEVSTACK_WORKSPACE)/edx-theme-codebase  ## Not sure if this is needed

	## Mac OSX might compalin about the `-d`, we can remove it temp.
	sudo ln -s -d /edx/var/edxapp/themes/edx-theme-customers $(DEVSTACK_WORKSPACE)/edx-theme-codebase/customer_specific

tahoe.provision:  ## Make the devstack more Tahoe'ish
	make tahoe.chown
	cat $(DEVSTACK_WORKSPACE)/devstack/provision-tahoe.py > $(DEVSTACK_WORKSPACE)/src/provision-tahoe.py
	make COMMAND='python /edx/src/provision-tahoe.py' tahoe.exec.edxapp
	rm $(DEVSTACK_WORKSPACE)/src/provision-tahoe.py
	make tahoe.theme.hack
	make tahoe.restart || true

tahoe.up:  ## Run the devstack with proper Tahoe settings, use instead of `$ make dev.up`
	make dev.up
	@sleep 1
	make tahoe.provision
	make tahoe.chown

tahoe.envs._delete:  ## Remove settings, in prep for resetting it
	sudo rm -rf $(DEVSTACK_WORKSPACE)/src/edxapp-envs

tahoe.restart:  ## Restarts both of LMS and Studio python processes while keeping the same container
	make lms-restart
	make studio-restart
	make amc-restart

amc.provision:  ## Initializes the AMC
	docker exec -it tahoe.devstack.amc python manage.py migrate
	make COMMAND='python manage.py lms create_oauth2_client http://localhost:9000/     http://localhost:9000/oauth2/access_token/ confidential --client_name AMC --client_id 6f2b93d5c02560c3f93f     --client_secret 2c6c9ac52dd19d7255dd569fb7eedbe0ebdab2db --trusted --settings=devstack_docker' SERVICE='lms' tahoe.exec.single
	docker exec -it tahoe.devstack.amc python manage.py create_devstack_superuser
	docker exec -it tahoe.devstack.amc-frontend npm install

amc-shell:
	docker exec -it tahoe.devstack.amc bash

amc-frontend-shell:
	docker exec -it tahoe.devstack.amc-frontend bash

amc-restart:
	docker exec -t tahoe.devstack.amc bash -c 'killall5'
	docker exec -t tahoe.devstack.amc-frontend bash -c 'killall5'
