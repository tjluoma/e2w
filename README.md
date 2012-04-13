
# Summary

This script can be used to create your own image hosting service which you can add images to via email.

It is designed to run on Mac OS X.

You do *not* have to be great at the command line to use it, you just have to have some patience to get through the initial setup.

If you can read instructions, you can use this.


## Problem

I don't like any of the existing 'free image hosting' services for the following reasons:

* shady Terms Of Service written in legalese which may or may not give them more rights than I want to give them
* they may disappear at any time (how much longer will any of these sites be around?)
* they put ads around my images. (I don't begrudge them wanting to offset their costs, but most of these sites are hideously ugly)
* they are usually *really* slow to load
* if I delete an image, is it *really* deleted, or is it still on their server somewhere?
* will it work with my favorite {Twitter/Facebook/Tumblr/etc} app?
* I hate going through the OAuth/xAuth dance to approve these sites to access my {Twitter/Facebook/Tumblr} feed. And I'm always concerned about what it might do that I didn't expect it to do (i.e. automatic posting)

Even if you find one you like ([mlkshk](http://mlkshk.com/) seems like the best one currently, and IIRC I read it's TOS and found it reasonable), there's no guarantee that they won't be sold and shut down (Hi Posterous!) or not sold and maybe going to be shut down but then maybe not (Hi Flickr!) or sold but "We're not going to *change* man!" (Hi Instagram!)

There are other, more minor, annoyances, such as the inability to chose the URL that you want, or services which automatically reducing the file size and then make you click on another link to open the full size, but those are the biggest concerns.

## Solution

I should host my own images.

## "But how?"

* I don't know how to write my own web app, nor do I want to.

* I want to be able to upload pictures via email. Most (read: 99.999%) of my pictures are taken on my iPhone. The iPhone lets me resize pictures when sending them (if I choose). My iPhone pictures get downloaded and stored anyway, so these will be *copies* and I don't mind if they are not full resolution, but if I *want* to send full resolution, that should work too.

* I want the Subject of the email that I send to be the `<title>` and `<h1>` of a web page for the image.

* I want the URL for the web page to be closely related to the URL for the image, so that one might be able to guess one from the other.

* Once the file is in place, I want to be notified very quickly, with both the URL for the image, and the URL for the web page (if applicable)

## Here is what you will need

* a Mac which is always on and always connected to the web.

* [Hazel](http://www.noodlesoft.com/hazel.php) to automatically process the files which SendToDropbox places in Dropbox.
	* Yes, you could do the same thing with Folder Actions or even launchd. I prefer Hazel. Feel free to fork.

* A hosting account at Dreamhost ***or any host which supports rsync/ssh***.
	* You *could* put the images in your ~/Dropbox/Public/ folder and link to them there (feel free to fork), but:
		* That assumes Dropbox will be around forever
		* That assumes you will always want to use Dropbox
		* That assumes you will never run out of space on your Dropbox
		* Dropbox will shut down public URLs if they get "too much" traffic. But what they consider to be "too much" is kept secret. The only way you'll know is when it gets shut down for 3 days.

* A [Google Voice account](http://voice.google.com). This will be used to send SMS with the URLs.
	* You could also use [Boxcar](http://boxcar.io/). Feel free to fork.

* [voicesms.rb](http://brettterpstra.com/sms-from-the-command-line-with-google-voice/) is a Ruby shell script by [Brett Terpstra](http://brettterpstra.com) (or, as you say, *Tirp*-stra) which makes it easy to send SMS via Google Voice.

* [multimarkdown](http://fletcherpenney.net/multimarkdown/) which you can get via [Homebrew](https://github.com/mxcl/homebrew). This will process your email and turn it into a web page. **Note:** If you have [MultiMarkdown Composer](http://itunes.apple.com/us/app/multimarkdown-composer/id473566589?mt=12) then the binary is already on your computer at `/Applications/MultiMarkdown Composer.app/Contents/Resources/multimarkdown`. You could link that to `/usr/local/bin/multimarkdown`

`ln -s "/Applications/MultiMarkdown Composer.app/Contents/Resources/multimarkdown" /usr/local/bin/multimarkdown`

* [jhead](http://www.sentex.net/~mwandel/jhead/) which you can also get via [Homebrew](https://github.com/mxcl/homebrew). This will solve the problem of image rotation from pictures taken from iOS devices. (This was the biggest problem I had to solve, actually.)


## Hazel

Create a folder ~/MailAttachments in Finder.

Then create a rule in Hazel for that folder:

![](http://images.luo.ma/e2w/Hazel.png)

which says "Whenever you find an image, run this script (e2w.sh).

You could call the folder something else, but then you'll have to change the AppleScript and `e2w.sh`

## Mail.app

Create a rule in Mail.app to run the `SaveAttachments.scpt` whenever you receive email to a specific email address. Most email services (including iCloud and Gmail) support "plus addressing" so if your email address is `jpublic@gmail.com` then you can *also* receive email at `jpublic+SomeSecretWord@gmail.com`

Have the mail rule process on any message sent to `jpublic+SomeSecretWord@gmail.com`. Then add `jpublic+SomeSecretWord@gmail.com` to your iPhone address book so you don't have to remember it.

I also have my rule mark the message as "Read" and flag it, so I can tell that it has been processed by the script. (This is handy if you are on your iPhone and want to see if the message has reached the server.)

I set Mail.app to check for new email every 1 minute.

## e2w-SaveAttachments.scpt

Save this file as an AppleScript anywhere. Then point the Mail.app rule at it. Be sure that it ends with `.scpt`

Also, be sure to change both instances of "Users:tjluoma:MailAttachments:" to whatever the path to your folder is (it's just the `tjluoma` part that needs to be changed).

Note: I am a complete novice at AppleScript. This script could be improved to save each picture and body to a separate folder (and then we'd have to run e2w.sh on that folder instead).

If you send two messages at the same time, there's a risk that it could get mucked up. But it works well enough for my purposes, and all of my attempts to make the script more error-proof failed.


## Configure voicesms.rb

Get the code from <http://brettterpstra.com/sms-from-the-command-line-with-google-voice/>
and save it to `voicesms.rb` and put it somewhere in your $PATH.

*Then* create another shell script called `textme.sh` that looks like this:


	#!/bin/zsh

	COUNT="0"

	# How many times do you want to try?
	MAXCOUNT="10"

	while [ "$COUNT" -le "$MAXCOUNT" ]
	do

		voicesms.rb -n +15554443333 -m "$@" && exit 0

		# increment counter
		((COUNT++))

	done

	exit 0
	# end of shell script

***Replace*** `15554443333` with your phone number. Note that the `1` is required for USA phone numbers.

Why bother with a `textme.sh` wrapper? Because sometimes `voicesms.rb` will fail. You want to try it more than once. The loop will end once it succeeds. Then you can use `textme.sh FOO` to send yourself a message `FOO` in other scripts.

Be sure to make the scripts executable:

	chmod a+x voicesms.rb

	chmod a+x textme.sh

## Setup ssh for password-less rsync

You'll want to be able to `ssh` to your server without entering a password. To do this you'll need to create public and private keys.

*On your Mac* (on the Mac which will be running Hazel and Dropbox), go to `/Applications/Utilities/Terminal.app` and type this:

	ssh-keygen -t dsa -f ~/.ssh/id_dsa -C "$USER@$HOST"

you will see this

	Generating public/private dsa key pair.
	Enter passphrase (empty for no passphrase):

***Enter a passphrase.*** A *passphrase* is like a password but it might be longer. See [this post from Agilebits](http://blog.agilebits.com/2011/08/10/better-master-passwords-the-geek-edition/) for a description of a passphrase, but I'm going to use "correct horse battery staple" as my example.

Once you have created your passphrase, you will need to copy ~/.ssh/id_dsa.pub to your remote server. This is where you want the images to end up for public web hosting. Assume the server's name is `your.server.example.com`:

	scp ~/.ssh/id_dsa.pub your.server.example.com:my-new-pubkey.pub

You will be prompted to enter your `your.server.example.com` password (which is *not* the same as your SSH passphrase).

Then you will need to log in to `your.server.example.com` using ssh:

	ssh your.server.example.com -l $USER

*Note: if your username on `your.server.example.com` is not the same as your username on your Mac, change `$USER` to whatever your login name is on `your.server.example.com`.*

Once you are logged in, you need to add 'my-new-pubkey.pub' to ~/.ssh/authorized_keys.

	mkdir -p ~/.ssh

	cat ~/my-new-pubkey.pub >> ~/.ssh/authorized_keys

If you do not see any output, that means it worked. (Unix is like that.)

Now, log *out* of `your.server.example.com` (type 'exit' and hit enter/return).

Now try connecting again:

	ssh your.server.example.com -l $USER

*Note: if your username on `your.server.example.com` is not the same as your username on your Mac, change `$USER` to whatever your login name is on `your.server.example.com`.*

When you do that, you should see a dialog box like this:

![](http://images.luo.ma/e2w/Keychain.jpg)

*That* is where you enter the passphrase you created earlier. ***Be sure to save it in your Keychain!!!***

After you go through these steps *ONE TIME* you can then log into your server without having to enter a password, because the Keychain will remember your passphrase, and then the SSH keys will be used.

**If this step isn't done correctly, nothing else will work.**


## Once it is all set up, here's how to use it: ##


1. Take a picture
2. Email that picture to your `jpublic+SomeSecretWord@gmail.com` address
3. Wait for an SMS, which will contain a URL to the image itself, as well as to the web page version (if applicable)

## Notes ##


* I use the [Google Voice app for iPhone](http://itunes.apple.com/us/app/google-voice/id318698524?mt=8) for push notifications
* I use a POP3 account in Mail.app. Trying to use an IMAP account seemed to cause problems the body of the email being delivered. POP3 seems to wait until the entire message is downloaded before processing. You could even create a new Gmail account, enable POP, and just use that account for these purposes.


