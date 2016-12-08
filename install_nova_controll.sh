#!/bin/bash
#log function
NAMEHOST=$HOSTNAME
function log_info ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-liberty

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-liberty

}

function fn_log ()  {
if [  $? -eq 0  ]
then
	log_info "$@ sucessed."
	echo -e "\033[32m $@ sucessed. \033[0m"
else
	log_error "$@ failed."
	echo -e "\033[41;37m $@ failed. \033[0m"
	exit
fi
}
if [ -f  /etc/openstack-liberty_tag/install_glance.tag ]
then 
	log_info "glance have installed ."
else
	echo -e "\033[41;37m you should install glance first. \033[0m"
	exit
fi


if [ -f  /etc/openstack-liberty_tag/install_nova.tag ]
then 
	echo -e "\033[41;37m you haved install nova \033[0m"
	log_info "you haved install nova."	
	exit
fi

if [ -f $PWD/lib/var_config ]
then
   source $PWD/lib/var_config
else
   echo "$PWD/lib/var_config not exit"
   fn_log "$PWD/lib/var_config not exit"
   exit 1
fi

#create nova databases 
function  fn_create_nova_database () {
mysql  -e "CREATE DATABASE nova;" &&  mysql  -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'Secure_pass_123';" && mysql  -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'Secure_pass_123';" && mysql  -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@$HOSTNAME IDENTIFIED BY 'Secure_pass_123';"
fn_log "create nova databases"
}
mysql  -e "show databases ;" >test
DATABASENOVA=`cat test | grep nova`
rm -rf test 
if [ ${DATABASENOVA}x = novax ]
then
	log_info "nova database had installed."
else
	fn_create_nova_database
fi


source /root/admin-openrc.sh

USER_NOVA=`keystone user-list | grep nova | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_NOVA}x = novax ]
then
	log_info "keystone user had created  nova"
else
	 keystone user-create --name nova --pass Secure_pass_123
	fn_log "keystone user-create --name nova --pass Secure_pass_123"
	keystone user-role-add --user nova --tenant service --role admin
	fn_log "keystone user-role-add --user nova --tenant service --role admin"
fi



SERVICE_NOVA=`keystone service-list | grep nova | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${SERVICE_NOVA}x = novax ]
then 
	log_info "openstack service create nova."
else
	keystone service-create --name nova --type compute --description "Openstack Compute"
	fn_log "keystone service-create --name nova --type compute --description "Openstack Compute" "
fi


ENDPOINT_LIST_NOVA=`keystone endpoint-list  | grep 8774  | wc -l`

if [  ${ENDPOINT_LIST_NOVA}  -eq 1  ]
then
	log_info "keystone endpoint create nova."
else
	keystone endpoint-create --service-id $(keystone service-list | awk '/ compute / {print $2}') --publicurl http://$VIP:8774/v2/%\(tenant_id\)s  --internalurl http://$VIP:8774/v2/%\(tenant_id\)s  --adminurl http://$VIP:8774/v2/%\(tenant_id\)s --region RegionOne
	fn_log "keystone endpoint-create --service-id $(keystone service-list | awk '/ compute / {print $2}') --publicurl http://$VIP:8774/v2/%\(tenant_id\)s  --internalurl http://$VIP:8774/v2/%\(tenant_id\)s  --adminurl http://$VIP:8774/v2/%\(tenant_id\)s --region RegionOne"
fi


yum clean all && yum install openstack-nova-api  openstack-nova-conductor openstack-nova-console   openstack-nova-novncproxy openstack-nova-scheduler   python-novaclient -y
fn_log "yum clean all && yum install openstack-nova-api  openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler python-novaclient -y"


[ -f /etc/nova/nova.conf_bak ]  || cp -a /etc/nova/nova.conf /etc/nova/nova.conf_bak
openstack-config --set  /etc/nova/nova.conf database connection  mysql://nova:Secure_pass_123@${VIP}/nova
openstack-config --set  /etc/nova/nova.conf DEFAULT rpc_backend  rabbit
openstack-config --set  /etc/nova/nova.conf DEFAULT rabbit_host  ${HOSTNAME}
openstack-config --set  /etc/nova/nova.conf DEFAULT rabbit_userid  guest
openstack-config --set  /etc/nova/nova.conf DEFAULT rabbit_password  Secure_pass_123
openstack-config --set  /etc/nova/nova.conf DEFAULT auth_strategy  keystone
openstack-config --set  /etc/nova/nova.conf DEFAULT metadata_manager nova.api.manager.MetadataManager
openstack-config --set  /etc/nova/nova.conf DEFAULT metadata_listen ${MYIP}
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_host  ${VIP}
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_uri  http://${VIP}:5000/v2.0
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set  /etc/nova/nova.conf keystone_authtoken admin_tenant_name  service
openstack-config --set  /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set  /etc/nova/nova.conf keystone_authtoken admin_password  Secure_pass_123
openstack-config --set  /etc/nova/nova.conf DEFAULT my_ip ${MYIP}
openstack-config --set  /etc/nova/nova.conf DEFAULT verbose True
openstack-config --set  /etc/nova/nova.conf DEFAULT network_api_class  nova.network.neutronv2.api.API
openstack-config --set  /etc/nova/nova.conf DEFAULT security_group_api  neutron
openstack-config --set  /etc/nova/nova.conf DEFAULT linuxnet_interface_driver  nova.network.linux_net.LinuxOVSInterfaceDriver
openstack-config --set  /etc/nova/nova.conf DEFAULT firewall_driver  nova.virt.firewall.NoopFirewallDriver
openstack-config --set  /etc/nova/nova.conf DEFAULT vncserver_listen  0.0.0.0
openstack-config --set  /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address  ${MYIP}
openstack-config --set  /etc/nova/nova.conf DEFAULT  novncproxy_base_url  http://${VIP}:6080/vnc_auto.html
openstack-config --set  /etc/nova/nova.conf glance host  $VIP
openstack-config --set  /etc/nova/nova.conf DEFAULT enabled_apis ec2,osapi_compute,metadata
openstack-config --set  /etc/nova/nova.conf neutron service_metadata_proxy True
openstack-config --set  /etc/nova/nova.conf neutron metadata_proxy_shared_secret 9e172ca9a95c04f0169d
openstack-config --set  /etc/nova/nova.conf neutron url http://$VIP:9696
openstack-config --set  /etc/nova/nova.conf neutron admin_username neutron
openstack-config --set  /etc/nova/nova.conf neutron admin_password Secure_pass_123
openstack-config --set  /etc/nova/nova.conf neutron admin_tenant_name service
openstack-config --set  /etc/nova/nova.conf neutron admin_auth_url http://$VIP:5000/v2.0
openstack-config --set  /etc/nova/nova.conf neutron auth_strategy keystone
fn_log "config /etc/nova/nova.conf "

HARDWARE=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ ${HARDWARE}  -eq 0 ]
then
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu
	log_info  "openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu sucessed."
else
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  kvm
	log_info  "openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu sucessed."
fi


/bin/sh  -c  "nova-manage db sync"
fn_log "/bin/sh  -c  "nova-manage db sync" "

systemctl enable openstack-nova-api.service  openstack-nova-consoleauth.service  openstack-nova-scheduler.service openstack-nova-conductor.service   openstack-nova-novncproxy.service && systemctl start openstack-nova-api.service    openstack-nova-consoleauth.service  openstack-nova-scheduler.service openstack-nova-conductor.service   openstack-nova-novncproxy.service
fn_log "systemctl enable openstack-nova-api.service    openstack-nova-consoleauth.service  openstack-nova-scheduler.service openstack-nova-conductor.service   openstack-nova-novncproxy.service && systemctl start openstack-nova-api.service    openstack-nova-consoleauth.service  openstack-nova-scheduler.service openstack-nova-conductor.service   openstack-nova-novncproxy.service"



source /root/admin-openrc.sh
nova service-list 
NOVA_STATUS=`nova service-list | awk -F "|" '{print$7}'  | grep -v State | grep -v ^$ | grep down`
if [  -z ${NOVA_STATUS} ]
then
	echo "nova status is ok"
	log_info  "nova status is ok"
	echo -e "\033[32m nova status is ok \033[0m"
else
	echo "nova status is down"
	log_error "nova status is down."
	exit
fi

nova endpoints
fn_log "nova endpoints"
nova image-list
fn_log "nova image-list"

NOVA_IMAGE_STATUS=` nova image-list  | grep cirros-0.3.4-x86_64  | awk -F "|"  '{print$4}'`
if [ ${NOVA_IMAGE_STATUS}  = ACTIVE ]
then
	log_info  "nova image status is ok"
	echo -e "\033[32m nova image status is ok \033[0m"
else
	echo "nova image status is error."
	log_error "nova image status is error."
	exit
fi




echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###         install nova sucessed           #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack-liberty_tag ]
then 
	mkdir -p /etc/openstack-liberty_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-liberty_tag/install_nova.tag




