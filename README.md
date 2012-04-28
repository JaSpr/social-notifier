#############
### ABOUT ###
#############

This application was written and tested for ruby1.9.2 and is designed to
work in conjunction with the libnotify notification daemon to display a
notification on the desktop whenever a feed finds a new message from any
of the following services:

 * Twitter          (Home feed, list, or search)
 * Gmail            (Inbox or any other label)
 * Google Voice     (SMS, Missed Calls, or Voicemails)
 * RSS / Atom Feeds
 * Github           (Commit messages and affected files)
 * SVN              (Commit messages and affected files)

Since it is presently using libnotify, it is designed to work in Linux,
Although I have heard of windows ports for libnotify, and additional
notifier classes could also be written for windows or mac notification
libraries.

One running instance of the daemon can contain multiple and mixed feeds
from which to retrieve updates.  Each type of request (i.e. Gmail, Gvoice,
Twitter, etc.) is added to its own stack, and that stack will be scanned
independently.  One request from the request group will be sent every
15 seconds. (This means that different types of requests will be scanned
concurrently).

Future goals are to allow for Facebook feeds as well.


#####################
### PREREQUISITES ###
#####################

To use this application in its present state, you must have the following
gems installed: (use commands below).

    sudo apt-get install ruby1.9.1-dev            # To allow installing gems which require mkmf

    sudo gem install libnotify                    # For using libnotify

    sudo apt-get install libxml2-dev libxslt1-dev # For nokogiri
    sudo gem install nokogiri                     # For using Google Voice, SVN, GitHub

    sudo gem install simple-rss      # For using Gmail, RSS/Atom
    sudo gem install twitter         # For using Twitter

    sudo apt-get install subversion  # For using SVN (requires the command line client)


*** Following facebook feeds isn't working right now, as the offline_access
*** token is being deprecated.

    sudo gem install fb_graph

*** config-dist.rb must be filled out and renamed as config.rb for the
*** application to run, and you must fill out your twitter settings in
*** that file (follow the instructions in that file) to access the
*** Twitter API


####################
### INSTRUCTIONS ###
####################


### STARTING THE DAEMON:

    ruby application.rb start


### ADDING REQUESTS TO THE STACK:

Twitter:

    ruby application.rb add twitter home
    ruby application.rb add twitter list [list-owner] [list]
    ruby application.rb add twitter search keyword
    ruby application.rb add twitter search "key words"

Gmail (view unread within any label):

    ruby application.rb add gmail [label or 'inbox'] [username] [password]
    ruby application.rb add gmail inbox [username/email] [password]
    ruby application.rb add gmail work  [username/email] [password]

Google Voice: (unread texts, voicemails, or missed calls)

    ruby application.rb add google-voice sms    [username/email] [password]
    ruby application.rb add google-voice vm     [username/email] [password]
    ruby application.rb add google-voice missed [username/email] [password]

RSS / ATOM

    ruby application.rb add rss http://path.com/url/to/rss/feed
    ruby application.rb add rss http://path.com/url/to/rss/feed [username] [password]  # (optional un/pass)

Subversion

    ruby application.rb add [svn or subversion] http(s)://path.com/url/to/repo [username] [password]
    ruby application.rb add subversion http://path.com/url/to/repo
    ruby application.rb add svn https://path.com/url/to/repo [username] [password]

GitHub

    ruby application.rb add github [github commits atom URL]
    ruby application.rb add github https://github.com/JaSpr/social-notifier/commits/master.atom

These commands all return a numbered list of requests in your stack,
but you can directly query the stack without adding any new requests...


### LISTING REQUESTS IN THE STACK:

    ruby application.rb list


### DELETING REQUESTS FROM THE STACK:

    ruby application.rb delete [entry type:entry index]
    ruby application.rb delete gmail:1

After deletion, the entry number will not be reassigned, so running
the command twice won't delete another entry.


### STOPPING THE DAEMON:

    ruby application.rb stop


#################
### DEBUGGING ###
#################

A storage directory is created in your home directory in a directory named
.social-notifier .  This directory contains a subdirectory 'log' which
contains the application log ( everything purposefully logged to the output )
and the debug log, which is lists ruby debug messages.

tail -f ~/.social-notifier/log/*

Additionally, a twitter-images folder is created to store Twitter user images
so that they can be displayed with the tweet notification.