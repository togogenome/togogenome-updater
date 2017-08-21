#!/usr/bin/env ruby

require 'rubygems'
require 'json/ld'

input = JSON.parse %({
  "@context": {
    "name": "http://xmlns.com/foaf/0.1/name",
    "homepage": "http://xmlns.com/foaf/0.1/homepage",
    "avatar": "http://xmlns.com/foaf/0.1/avatar"
  },
  "name": "Manu Sporny",
  "homepage": "http://manu.sporny.org/",
  "avatar": "http://twitter.com/account/profile_image/manusporny"
})
puts JSON::LD::API.expand(input)
