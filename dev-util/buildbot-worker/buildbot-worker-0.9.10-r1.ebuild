# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="5"
PYTHON_COMPAT=( python2_7 python3_5 )

EGIT_REPO_URI="https://github.com/buildbot/buildbot.git"

[[ ${PV} == *9999 ]] && inherit git-r3
inherit readme.gentoo user distutils-r1

DESCRIPTION="BuildBot Worker (slave) Daemon"
HOMEPAGE="https://buildbot.net/ https://github.com/buildbot/buildbot https://pypi.python.org/pypi/buildbot-worker"

MY_PV="${PV/_p/.post}"
MY_P="${PN}-${MY_PV}"
[[ ${PV} == *9999 ]] || SRC_URI="mirror://pypi/${PN:0:1}/${PN}/${MY_P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
if [[ ${PV} == *9999 ]]; then
	KEYWORDS=""
else
	KEYWORDS="~amd64"
fi
IUSE="test"

RDEPEND=">=dev-python/setuptools-21.2.1[${PYTHON_USEDEP}]
	>=dev-python/twisted-17.5.0[${PYTHON_USEDEP}]
	dev-python/future[${PYTHON_USEDEP}]
	!<dev-util/buildbot-0.9.7
"
DEPEND="${RDEPEND}
	test? (
		dev-python/mock[${PYTHON_USEDEP}]
		dev-python/setuptools_trial[${PYTHON_USEDEP}]
	)
"

S="${WORKDIR}/${MY_P}"
[[ ${PV} == *9999 ]] && S=${S}/slave

pkg_setup() {
	enewuser buildbot

	DOC_CONTENTS="The \"buildbot\" user and the \"buildbot_worker\" init script has been added
		to support starting buildbot_worker through Gentoo's init system. To use this,
		execute \"emerge --config =${CATEGORY}/${PF}\" to create a new instance.
		Set up your build worker following the documentation, make sure the
		resulting directories are owned by the \"buildbot\" user and point
		\"${ROOT}etc/conf.d/buildbot_worker.myinstance\" at the right location.
		The scripts can	run as a different user if desired."
}

python_test() {
	distutils_install_for_testing

	esetup.py test || die "Tests failed under ${EPYTHON}"
}

python_install_all() {
	distutils-r1_python_install_all

	doman docs/buildbot-worker.1

	newconfd "${FILESDIR}/buildbot_worker.confd2" buildbot_worker
	newinitd "${FILESDIR}/buildbot_worker.initd2" buildbot_worker

	readme.gentoo_create_doc
}

pkg_postinst() {
	readme.gentoo_print_elog

	if [[ -n ${REPLACING_VERSIONS} ]]; then
		ewarn
		ewarn "Starting with buildbot-worker-0.9.10-r1, more than one instance of a buildbot_worker"
		ewarn "can be run simultaneously. Note that \"BASEDIR\" in the buildbot_worker configuration file"
		ewarn "is now the common base directory for all instances. If you are migrating from an older"
		ewarn "version, make sure that you copy the current contents of \"BASEDIR\" to a subdirectory."
		ewarn "The name of the subdirectory corresponds to the name of the buildbot_worker instance."
		ewarn "In order to start the service running OpenRC-based systems need to link to the init file:"
		ewarn "    ln --symbolic --relative /etc/init.d/buildbot_worker /etc/init.d/buildbot_worker.myinstance"
		ewarn "    rc-update add buildbot_worker.myinstance default"
		ewarn "    /etc/init.d/buildbot_worker.myinstance start"
		ewarn "Systems using systemd can do the following:"
		ewarn "    systemctl enable buildbot_worker@myinstance.service"
		ewarn "    systemctl enable buildbot_worker.target"
		ewarn "    systemctl start buildbot_worker.target"
	fi
}

pkg_config() {
	local buildworker_path="/var/lib/buildbot_worker"
	einfo "This will prepare a new buildbot_worker instance in ${buildworker_path}."
	einfo "Press Control-C to abort."

	einfo "Enter the name for the new instance: "
	read instance_name
	[[ -z "${instance_name}" ]] && die "Invalid instance name"

	local instance_path="${buildworker_path}/${instance_name}"
	if [[ -e "${instance_path}" ]]; then
		eerror "The instance with the specified name already exists:"
		eerror "${instance_path}"
		die "Instance already exists"
	fi

	local buildbot="/usr/bin/buildbot"
	if [[ ! -d "${buildworker_path}" ]]; then
		mkdir --parents "${buildworker_path}" || die "Unable to create directory ${buildworker_path}"
	fi
	"${buildbot}" create-master "${instance_path}" &>/dev/null || die "Creating instance failed"
	chown --recursive buildbot "${instance_path}" || die "Setting permissions for instance failed"
	mv "${instance_path}/master.cfg.sample" "${instance_path}/master.cfg" \
		|| die "Moving sample configuration failed"
	ln --symbolic --relative "/etc/init.d/buildbot_worker" "/etc/init.d/buildbot_worker.${instance_name}" \
		|| die "Unable to create link to init file"

	einfo "Successfully created a buildbot_worker instance at ${instance_path}."
	einfo "To change the default settings edit the buildbot.tac file in this directory."
}
