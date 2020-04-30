lms-djangoshell:
	make tahoe.exec.single COMMAND="./manage.py lms shell --settings=devstack_docker" SERVICE=lms

chef.clear_completions:
	@echo -e "${yellow}Deleting all BlockCompletion, StaleCompletion, Aggregator objects!${normal}"
	@make tahoe.exec.single COMMAND="echo \'from completion.models import BlockCompletion; from completion_aggregator.models import Aggregator, StaleCompletion; BlockCompletion.objects.all().delete(); Aggregator.objects.all().delete(); StaleCompletion.objects.all().delete()\' | ./manage.py lms shell --settings=devstack_docker" SERVICE=lms
