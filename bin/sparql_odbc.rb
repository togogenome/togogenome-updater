#!/usr/bin/env ruby

require "rubygems"
require "sequel"

class SPARQL_ODBC
  # db_name is defined at /etc/odbc.ini or ~/.odbc.ini"
  def initialize(odbc_db_name, user, password)
    @db_name = odbc_db_name
    @user = user
    @pass = password
#    connect()
  end

  def connect()
    @conn = Sequel.odbc("#{@db_name}", :user => "#{@user}", :password => "#{@pass}")
  end

  def query(sparql)
    connect()
    sparql_isql = "SPARQL " + sparql
#    result = Sequel.odbc("#{@db_name}", :user => "#{@user}", :password => "#{@pass}")["#{sparql_isql}"].all
    result = @conn["#{sparql_isql}"].all
    disconnect()
    return result
  end

  def disconnect()
    @conn.disconnect
    #http://d.hatena.ne.jp/shibason/20100304/1267697379
    Sequel::DATABASES.delete(@conn)
  end
end

