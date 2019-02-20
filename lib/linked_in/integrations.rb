module LinkedIn
  # Integrations APIs
  #
  # @see https://docs.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/share-on-linkedin
  #
  # LinkedIn's v2 API adherence to the documentation is shaky at best. Several of
  # the calls simply don't work if you, e.g., pass the URN in as a path element
  # for a resource - you have to use the ids=[URN] format w/ a single URN. Or
  # sometimes passing in an "actor" parameter in the request body simply doesn't
  # work, and you have to pass it in as a URL parameter. What you see in this
  # file is the result of trial-and-error getting these endpoints to work, and the
  # inconsistency is usually a result of either misunderstanding the docs or the
  # API not working as advertised. It's also a bit unclear when the API wants
  # an activity URN vs, e.g., an article URN. Caveat emptor.
  #
  # [(contribute here)](https://github.com/mdesjardins/linkedin-v2)
  class Integrations < APIResource

    # Create one ugcPosts from a person.
    #
    # Permissions:
    #  1.) For personal shares, you may only post shares as the authorized member.
    #
    # @see https://docs.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/share-on-linkedin#api-request
    #
    # @option options [String] :author, the URN of the entity posting the share.
    # @return [LinkedIn::Mash]
    #
    def ugc_share(options = {})
      path = '/ugcPosts'
      defaults = {
        lifecycleState: 'PUBLISHED',
        visibility: {
          'com.linkedin.ugc.MemberNetworkVisibility' => 'PUBLIC'
        }
      }
      post(path, MultiJson.dump(defaults.merge(options)), 'Content-Type' => 'application/json')
    end

    # Uploads Integrations Asset to LinkedIn from a supplied URL.
    #
    # @see https://docs.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/share-on-linkedin#create-an-image-share
    #
    # @options options [String] :source_url, the URL to the content to be uploaded.
    # @options options [String] :owner, the URN of the entity posting the share.
    # @options options [Numeric] :timeout, optional timeout value in seconds, defaults to 300.
    # @return [LinkedIn::Mash]
    #
    def asset_upload(options = {})
      source_url = options.delete(:source_url)
      owner = options.delete(:owner)
      timeout = options.delete(:timeout) || DEFAULT_TIMEOUT_SECONDS
      path = '/v2/assets?action=registerUpload'

      body = {
        "registerUploadRequest": {
          "recipes": [
            "urn:li:digitalmediaRecipe:feedshare-image"
          ],
          "owner": owner,
          "serviceRelationships": [
            {
              "relationshipType": "OWNER",
              "identifier": "urn:li:userGeneratedContent"
            }
          ]
        }
      }

      response = @connection.post(path, MultiJson.dump(body), 'Content-Type' => 'application/json')
      parsed = Mash.from_json(response.body)
      upload_url = parsed.value.uploadMechanism.first[1].uploadUrl
      asset = parsed.value.asset

      media = open(source_url, 'rb')

      response =
        @connection.post(upload_url) do |req|
          req.headers['Accept'] = '*/*'
          req.headers['Content-Length'] = media.size.to_s
          req.headers['Content-Type'] = 'application/octet-stream'
          req.headers['x-li-format'] = nil
          req.options.timeout = timeout
          req.options.open_timeout = timeout
          req.body = media
        end

      return asset
    end
  end
end
