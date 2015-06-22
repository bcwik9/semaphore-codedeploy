class HookController < ApplicationController
  # Add a semaphore hook to hit this action
  def create
    # grab important params from Semaphore payload
    project = params[:project_name]
    branch = params[:branch_name].gsub '/', '_'
    commit_sha = params[:commit][:id]
    author = params[:commit][:author_name]
    commit_message = params[:commit][:message]
    project_location = $1 if params[:commit][:url] =~ /github\.com\/(.+\/.+)\/commit\/.+$/
    passed = params[:result].to_s =~ /pass/i

    # only deploy if build passed
    if not passed
      render nothing: true
      return
    end

    # download tar file from git
    git_token = ENV['GITHUB_CODEDEPLOY_TOKEN'] # used for private repos
    tar_filename = File.join Dir.pwd, "#{project}_#{branch}.tar"
    download_cmd = "wget https://api.github.com/repos/#{project_location}/tarball/#{commit_sha} -O #{tar_filename}"
    unless git_token.nil? or git_token.empty?
      # add authentication for private git repos if necessary
      download_cmd += " --header='Authorization: token #{git_token}'"
    end
    # run the command!
    system download_cmd

    # ensure we downloaded the file
    unless File.exist? tar_filename
      raise "File #{tar_filename} not found. Maybe you need to specify a GitHub Key for a private repo? export GITHUB_CODEDEPLOY_TOKEN=<key>"
    end

    # process the file so there's no top level folder
    # first, unzip and remove old file
    s3_bucket_name = "#{project}_temp_codedeploy_files"
    FileUtils.mkdir_p s3_bucket_name
    system "tar -xf #{tar_filename} -C #{s3_bucket_name}"
    FileUtils.rm_f tar_filename
    # zip up files to new tar without top level directory
    rails_dir = Dir.glob("#{s3_bucket_name}/*").first
    Dir.chdir(rails_dir) do
      system "tar -cf #{tar_filename} ./"
    end
    # clean up
    FileUtils.rm_rf s3_bucket_name

    # push downloaded file to AWS S3
    Aws::S3::Client.new.create_bucket(acl: "authenticated-read", bucket: s3_bucket_name)
    s3_file_obj = Aws::S3::Resource.new.bucket(s3_bucket_name).object(File.basename(tar_filename))
    s3_file_obj.upload_file tar_filename
    # clean up
    FileUtils.rm_f tar_filename

    # deploy
    codedeploy_client = Aws::CodeDeploy::Client.new
    codedeploy_client.create_deployment(
                                        application_name: project,
                                        deployment_group_name: branch,
                                        # description has a 100 char limit
                                        description: "#{author}: #{commit_message}"[0,99],
                                        revision: {
                                          revision_type: "S3",
                                          s3_location: {
                                            bucket: s3_bucket_name,
                                            key: File.basename(tar_filename),
                                            bundle_type: "tar"
                                          }
                                        }
                                        )
    
    render nothing: true
  end
end
