import hudson.model.BooleanParameterValue
import hudson.model.Cause
import hudson.model.CauseAction
import hudson.model.ParametersAction
import hudson.model.StringParameterValue
import hudson.triggers.SCMTrigger
import jenkins.model.Jenkins

def ensureScmPolling(String jobName, String spec) {
  def j = Jenkins.get()
  def job = j.getItemByFullName(jobName)
  if (job == null) {
    println("Job not found for SCM polling: ${jobName}")
    return
  }

  def existing = job.getSCMTrigger()
  if (existing == null || existing.spec != spec) {
    def trigger = new SCMTrigger(spec)
    job.addTrigger(trigger)
    trigger.start(job, true)
    job.save()
    println("Configured SCM polling for ${jobName} with spec ${spec}")
  } else {
    println("SCM polling already configured for ${jobName} with spec ${spec}")
  }
}

def scheduleDeveloperBuildOnce() {
  def j = Jenkins.get()
  def marker = new File(j.rootDir, "developer_build_once.marker")
  if (marker.exists()) {
    println("developer_build one-shot already scheduled before; skip")
    return
  }

  def job = j.getItemByFullName("developer_build")
  if (job == null) {
    println("Job not found: developer_build")
    return
  }

  def params = [
    new StringParameterValue("PIPELINE_TARGET", "developer_build"),
    new StringParameterValue("SERVICE_CATALOG", "release-baseline"),
    new StringParameterValue("DOCKERHUB_NAMESPACE", "luongtrz"),
    new StringParameterValue("DEPLOYER_ID", "devjenkins"),
    new StringParameterValue("DOMAIN_NAME", "storefront-devjenkins.yas.local"),
    new StringParameterValue("BACKOFFICE_DOMAIN_NAME", "backoffice-devjenkins.yas.local"),
    new StringParameterValue("SOURCE_REPO_URL", "https://github.com/nashtech-garage/yas.git"),
    new StringParameterValue("SOURCE_REPO_REF", "main"),
    new StringParameterValue("STOREFRONT_BRANCH", "main"),
    new StringParameterValue("BACKOFFICE_BRANCH", "main"),
    new StringParameterValue("STOREFRONT_BFF_BRANCH", "main"),
    new StringParameterValue("BACKOFFICE_BFF_BRANCH", "main"),
    new StringParameterValue("PRODUCT_BRANCH", "main"),
    new StringParameterValue("MEDIA_BRANCH", "main"),
    new StringParameterValue("CART_BRANCH", "main"),
    new StringParameterValue("CUSTOMER_BRANCH", "main"),
    new StringParameterValue("ORDER_BRANCH", "main"),
    new StringParameterValue("INVENTORY_BRANCH", "main"),
    new StringParameterValue("TAX_BRANCH", "main"),
    new StringParameterValue("SEARCH_BRANCH", "main"),
    new StringParameterValue("SAMPLEDATA_BRANCH", "main"),
    new BooleanParameterValue("DELETE_NAMESPACE", true),
    new BooleanParameterValue("ALLOW_SHARED_ENVIRONMENT_CLEANUP", false),
    new BooleanParameterValue("ALLOW_SHARED_NAMESPACE_DELETE", false),
  ]

  def item = job.scheduleBuild2(
    0,
    new CauseAction(new Cause.RemoteCause("localhost-init", "schedule correct developer_build evidence run")),
    new ParametersAction(params)
  )
  if (item != null) {
    marker.text = "scheduled\n"
  }
  println("Scheduled developer_build with PIPELINE_TARGET=developer_build: ${item != null}")
}

ensureScmPolling("project2-yas-ci", "H/2 * * * *")
scheduleDeveloperBuildOnce()
