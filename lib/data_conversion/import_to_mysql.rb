# Copyright (c) 2010, Diaspora Inc.  This file is
# licensed under the Affero General Public License version 3 or later.  See
# the COPYRIGHT file.

module DataConversion
  class ImportToMysql < DataConversion::Base

    def boolean_set(string)
      "#{string}= IF(STRCMP(@#{string},'false'), TRUE, FALSE)"
    end
    def nil_es(string)
      "#{string} = NULLIF(@#{string}, '')"
    end
    def unix_time(string)
      "#{string} = FROM_UNIXTIME(@#{string} / 1000)"
    end

    def import_raw
      truncate_tables

      import_raw_users
      import_raw_aspects
      import_raw_aspect_memberships
      import_raw_comments
      import_raw_invitations
      import_raw_notifications
      import_raw_people
      import_raw_profiles
      import_raw_posts
      import_raw_contacts
      import_raw_post_visibilities
      import_raw_requests
      import_raw_services
    end

    def process_raw_tables
      process_raw_users
      process_raw_aspects
      process_raw_services
      process_raw_people
      process_raw_contacts
      process_raw_aspect_memberships
      #invitations
      #requests
      #profiles
      #posts
      #post_visibilities
      #notifications
    end

    def truncate_tables
      Mongo::User.connection.execute "TRUNCATE TABLE mongo_users"
      Mongo::Aspect.connection.execute "TRUNCATE TABLE mongo_aspects"
      Mongo::AspectMembership.connection.execute "TRUNCATE TABLE mongo_aspect_memberships"
      Mongo::Comment.connection.execute "TRUNCATE TABLE mongo_comments"
      Mongo::Invitation.connection.execute "TRUNCATE TABLE mongo_invitations"
      Mongo::Notification.connection.execute "TRUNCATE TABLE mongo_notifications"
      Mongo::Person.connection.execute "TRUNCATE TABLE mongo_people"
      Mongo::Profile.connection.execute "TRUNCATE TABLE mongo_profiles"
      Mongo::Post.connection.execute "TRUNCATE TABLE mongo_posts"
      Mongo::Contact.connection.execute "TRUNCATE TABLE mongo_contacts"
      Mongo::PostVisibility.connection.execute "TRUNCATE TABLE mongo_post_visibilities"
      Mongo::Request.connection.execute "TRUNCATE TABLE mongo_requests"
      Mongo::Service.connection.execute "TRUNCATE TABLE mongo_services"
    end

    def process_raw_users
      log "Importing users to main table..."
      User.connection.execute <<-SQL
        INSERT INTO users
        SELECT mongo_users.* from mongo_users
      SQL
      log "Imported #{User.count} users."
    end

    def process_raw_aspects
      log "Importing aspects to main table..."
      Aspect.connection.execute <<-SQL
        INSERT INTO aspects
        SELECT mongo_aspects.id,
               mongo_aspects.name,
               users.id,
               mongo_aspects.created_at,
               mongo_aspects.updated_at,
               mongo_aspects.mongo_id,
               mongo_aspects.user_mongo_id
          FROM mongo_aspects
          INNER JOIN users ON (users.mongo_id = mongo_aspects.user_mongo_id)
      SQL
      log "Imported #{Aspect.count} aspects."
    end
    def process_raw_contacts
      log "Importing contacts to main table..."
      Contact.connection.execute <<-SQL
        INSERT INTO contacts
        SELECT mongo_contacts.id,
               users.id,
               people.id,
               mongo_contacts.pending,
               mongo_contacts.created_at,
               mongo_contacts.updated_at,
               mongo_contacts.mongo_id
          FROM mongo_contacts
          INNER JOIN (users, people) ON (users.mongo_id = mongo_contacts.user_mongo_id
                                         AND people.mongo_id = mongo_contacts.person_mongo_id)
      SQL
      log "Imported #{Contact.count} contacts."
    end
    def process_raw_aspect_memberships
      log "Importing aspect_memberships to main table..."
      AspectMembership.connection.execute <<-SQL
        INSERT INTO aspect_memberships
        SELECT mongo_aspect_memberships.id,
               aspects.id,
               contacts.id,
               mongo_aspect_memberships.created_at,
               mongo_aspect_memberships.updated_at
          FROM mongo_aspect_memberships INNER JOIN (aspects, contacts)
            ON (aspects.mongo_id = mongo_aspect_memberships.aspect_mongo_id AND contacts.mongo_id = mongo_aspect_memberships.contact_mongo_id)
      SQL
      log "Imported #{AspectMembership.count} aspect_memberships."
    end
    def process_raw_services
      log "Importing services to main table..."
      Service.connection.execute <<-SQL
        INSERT INTO services
        SELECT mongo_services.id,
               mongo_services.type,
               users.id,
               mongo_services.provider,
               mongo_services.uid,
               mongo_services.access_token,
               mongo_services.access_secret,
               mongo_services.nickname,
               mongo_services.created_at,
               mongo_services.updated_at,
               mongo_services.mongo_id,
               mongo_services.user_mongo_id
          FROM mongo_services INNER JOIN users ON (users.mongo_id = mongo_services.user_mongo_id)
      SQL
      log "Imported #{Service.count} services."
    end
    def process_raw_people
      log "Importing people to main table..."
      Person.connection.execute <<-SQL
        INSERT INTO people
        SELECT mongo_people.id,
               mongo_people.guid,
               mongo_people.url,
               mongo_people.diaspora_handle,
               mongo_people.serialized_public_key,
               users.id,
               mongo_people.created_at,
               mongo_people.updated_at,
               mongo_people.mongo_id
          FROM mongo_people LEFT JOIN users ON (users.mongo_id = mongo_people.owner_mongo_id)
      SQL
      log "Imported #{Person.count} people."
    end
    def import_raw_users
      log "Loading users file..."
      Mongo::User.connection.execute <<-SQL
        #{load_string("users")}
        #{infile_opts}
        (mongo_id, email, @username, serialized_private_key, encrypted_password,
         invites, @invitation_token, @invitation_sent_at, @getting_started,
         @disable_mail, language, @last_sign_in_ip, @last_sign_in_at,
         @reset_password_token, password_salt)
         SET #{unix_time("last_sign_in_at")},
         #{nil_es("invitation_token")},
         #{nil_es("username")},
         #{nil_es("last_sign_in_ip")},
         #{nil_es("reset_password_token")},
         #{boolean_set("getting_started")},
         #{boolean_set("disable_mail")};
      SQL
      log "Finished. Imported #{Mongo::User.count} users."
    end


    def import_raw_aspects
      log "Loading aspects file..."
      Mongo::Aspect.connection.execute <<-SQL
        #{load_string("aspects")}
        #{infile_opts}
        (mongo_id, name, user_mongo_id, @created_at, @updated_at)
        SET #{unix_time("created_at")},
        #{unix_time("updated_at")};
      SQL
      log "Finished. Imported #{Mongo::Aspect.count} aspects."
    end

    def import_raw_aspect_memberships
      log "Loading aspect memberships file..."
      Mongo::AspectMembership.connection.execute <<-SQL
        #{load_string("aspect_memberships")}
        #{infile_opts}
        (contact_mongo_id, aspect_mongo_id)
      SQL
      log "Finished. Imported #{Mongo::AspectMembership.count} aspect memberships."
    end

    def import_raw_comments
      log "Loading comments file..."
      Mongo::Comment.connection.execute <<-SQL
        #{load_string("comments")}
        #{infile_opts}
        (mongo_id, post_mongo_id, person_mongo_id, @diaspora_handle, text, @youtube_titles)
        SET guid = mongo_id,
        #{nil_es("youtube_titles")};
      SQL
      log "Finished. Imported #{Mongo::Comment.count} comments."
    end
    def import_raw_posts
      log "Loading posts file..."
      Mongo::Post.connection.execute <<-SQL
        #{load_string("posts")}
        #{infile_opts}
        (@youtube_titles,@pending,@created_at,@public,@updated_at,status_message_mongo_id,caption,remote_photo_path,remote_photo_name,random_string,image,mongo_id,type,diaspora_handle,person_mongo_id,message)
        SET guid = mongo_id,
        #{nil_es("youtube_titles")},
        #{unix_time("created_at")},
        #{unix_time("updated_at")},
        #{boolean_set("pending")},
        #{boolean_set("public")};
      SQL
      log "Finished. Imported #{Mongo::Post.count} posts."
    end
    def import_raw_contacts
      log "Loading contacts file..."
      Mongo::Contact.connection.execute <<-SQL
        #{load_string("contacts")}
        #{infile_opts}
        (mongo_id, user_mongo_id, person_mongo_id, @pending, @created_at, @updated_at)
        SET #{boolean_set("pending")};
      SQL
      log "Finished. Imported #{Mongo::Contact.count} contacts."
    end

    def import_raw_services
      log "Loading services file..."
      Mongo::Service.connection.execute <<-SQL
        #{load_string("services")}
        #{infile_opts}
        (mongo_id, type,user_mongo_id,@provider,@uid,@access_token,@access_secret,@nickname)
        SET #{nil_es("provider")},
        #{nil_es("uid")},
        #{nil_es("access_token")},
        #{nil_es("access_secret")},
        #{nil_es("nickname")};
      SQL
      log "Finished. Imported #{Mongo::Service.count} services."
    end

    def import_raw_post_visibilities
      log "Loading post visibilities file..."
      Mongo::PostVisibility.connection.execute <<-SQL
        #{load_string("post_visibilities")}
        #{infile_opts}
        (aspect_mongo_id, post_mongo_id)
      SQL
      log "Finished. Imported #{Mongo::PostVisibility.count} post visibilities."
    end

    def import_raw_requests
      log "Loading requests file..."
      Mongo::Request.connection.execute <<-SQL
        #{load_string("requests")}
        #{infile_opts}
        (mongo_id, recipient_mongo_id, sender_mongo_id, @aspect_mongo_id)
        SET #{nil_es("aspect_mongo_id")};
      SQL
      log "Finished. Imported #{Mongo::Request.count} requests."
    end
    def import_raw_invitations
      log "Loading invitations file..."
      Mongo::Invitation.connection.execute <<-SQL
        #{load_string("invitations")}
        #{infile_opts}
        (mongo_id, recipient_mongo_id, sender_mongo_id, aspect_mongo_id, message)
      SQL
      log "Finished. Imported #{Mongo::Invitation.count} invitations."
    end
    def import_raw_notifications
      log "Loading notifications file..."
      Mongo::Notification.connection.execute <<-SQL
        #{load_string("notifications")}
        #{infile_opts}
        (mongo_id,target_mongo_id,target_type,@unread)
        SET #{boolean_set("unread")};
      SQL
      log "Finished. Imported #{Mongo::Notification.count} notifications."
    end
    def import_raw_people
      log "Loading people file..."
      Mongo::Person.connection.execute <<-SQL
        #{load_string("people")}
        #{infile_opts}
        (@created_at,@updated_at,serialized_public_key,url,mongo_id,@owner_mongo_id,diaspora_handle)
        SET guid = mongo_id,
        #{nil_es("owner_mongo_id")},
        #{unix_time("created_at")},
        #{unix_time("updated_at")};
      SQL
      log "Finished. Imported #{Mongo::Person.count} people."
    end
    def import_raw_profiles
      log "Loading profiles file..."
      Mongo::Profile.connection.execute <<-SQL
        #{load_string("profiles")}
        #{infile_opts}
        (@image_url_medium,@searchable,@image_url,person_mongo_id,
        @gender,@diaspora_handle,birthday,@last_name,@bio,
        @image_url_small,@first_name)
        SET #{boolean_set("searchable")},
        #{nil_es("image_url_medium")},
        #{nil_es("image_url")},
        #{nil_es("gender")},
        #{nil_es("diaspora_handle")},
        #{nil_es("last_name")},
        #{nil_es("bio")},
        #{nil_es("image_url_small")},
        #{nil_es("first_name")};
      SQL
      #STRCMP returns 0 if the arguments are the same
      log "Finished. Imported #{Mongo::Profile.count} profiles."
    end
    def infile_opts
      <<-OPTS
          FIELDS TERMINATED BY ','
          ENCLOSED BY '"'
          IGNORE 1 LINES
OPTS
    end

    def load_string model_name
        "LOAD DATA INFILE '#{full_path}/#{model_name}.csv' INTO TABLE mongo_#{model_name}"
    end
  end
end
