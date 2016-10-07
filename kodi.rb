require 'base64'

module Kodi
  # Use the HTTP JSON-RPC API of Kodi to refresh the Kodi DB
  #
  # @param [String] login_pass
  #        The 'login:pass' pair to use to access Kodi's HTTP API
  #
  def self.refresh(login_pass)
    json_body = '{ "jsonrpc":"2.0","method":"VideoLibrary.Scan","id":"AliScript" }'
    headers = { 'Content-Type' => 'application/json' }
    headers['Authorization'] = 'Basic ' + Base64.encode64(login_pass) if login_pass

    req = Net::HTTP.new('localhost', 9870)
    resp, _ = req.post('/jsonrpc', json_body, headers)
    if resp.code.to_i == 200
      Log::success('Kodi Database update started')
    else
      Log::error("Failed to trigger Kodi Database update (#{resp.code})")
    end
  end
end