#!/bin/zsh
#automatically rename a picture and a text file, move them to another folder, and upload them to a server via rsync.

	# CHANGE THIS
	# This is the folder where local files will be MOVED TO when all the processing is done.
	# Note: this does NOT need to be the same as URL_PREFIX or REMOTE_DIRECTORY
	# it just happens to be similar in my example
	# It also does not have to be in your Dropbox.
TO_DIR="$HOME/Dropbox/Public/i.luo.ma"

	# CHANGE THIS
	# to the server name that you want to rsync to ('your.server.example.com')
REMOTE_SERVER='iceman.dreamhost.com'

	# CHANGE THIS
	# change 'i.luo.ma' to whatever directory you want to use on that server, such as 'public_html'
	# NOTE that the last part of the TO_DIR path will be copied here too, so this will
	# really translate to dh:./i.luo.ma/ for me
	# You should not need to include the path to your remote $HOME
REMOTE_DIRECTORY='i.luo.ma'

	# change this to your remote username
REMOTE_USERNAME='luomat'

	# CHANGE THIS:
	# this is the public URL where the images will be available
	# This is PROBABLY very similar to REMOTE_DIRECTORY but may not be, depending on how
	# your server is configured
URL_PREFIX='http://i.luo.ma'





#					You should not have to edit anything below here.






#					Proceed with caution.






#					Seriously.






#					p.s. I never said I was a good coder



NAME="$0:t"

LOG="$HOME/Library/Logs/$NAME.log"

zmodload zsh/datetime

timestamp () { strftime %Y-%m-%d--%H.%M.%S "$EPOCHSECONDS" }

log () {
	echo "$NAME@$HOST [$$] [`timestamp`]: $@" | tee -a "$LOG"
}

log "----- Starting up. Arguments: $@ -----"

die ()
{
	echo "$NAME@$HOST [`timestamp`]: $@" | tee -a "$LOG"

	# this way if something goes wrong, we'll know not to keep waiting
	textme.sh "$NAME@HOST [$$] failed to process $FROM_DIR at `timestamp`. Error message is: $@"

	exit 1
}


# This is where we check to make sure you have all the necessary parts
# you can remove these lines if you are SURE that they are all there
# but it doesn't take long to check

command which -s jhead			|| 	die "jhead not found in $PATH. See README"

command which -s multimarkdown	|| 	die "multimarkdown not found in $PATH. See README"

command which -s voicesms.rb	|| 	die "voicesms.rb not found in $PATH. See README"

command which -s textme.sh		|| 	die "textme.sh not found in $PATH. See README"









	## CHECK FOR EXISTING PROCESS
	# In practice this script shouldn't actually collide with itself all that often, but
	# if for some reason it does (i.e. Dropbox was lagging or not running)
	# we at least attempt not to overrun ourselves.
	# This could probably be more efficient, but it's not written for "enterprise" level use
PID_COUNT=$(ps auxwww | fgrep "$NAME" | fgrep -v fgrep | wc -l | awk '{print $1}')


while [[ "$PID_COUNT" -gt "1" ]]
do
	log "$NAME is already running PID_COUNT = $PID_COUNT, sleeping 30"
	sleep 30
	PID_COUNT=$(ps auxwww | fgrep "$NAME" | fgrep -v fgrep | wc -l | awk '{print $1}')
done

# This is where Mail.app has been told to store the files which come in
FROM_DIR="$HOME/MailAttachments"

	# Don't assume the user gave you good information

[[ -e "$FROM_DIR" ]] || die "FROM_DIR ($FROM_DIR) does not exist"
[[ -r "$FROM_DIR" ]] || die "FROM_DIR ($FROM_DIR) is not readable"
[[ -w "$FROM_DIR" ]] || die "FROM_DIR ($FROM_DIR) is not writable"
[[ -d "$FROM_DIR" ]] || die "FROM_DIR ($FROM_DIR) is not a directory"

log "FROM_DIR is $FROM_DIR and is a rw directory"

[[ -e "$TO_DIR" ]] || die "TO_DIR ($TO_DIR) does not exist"
[[ -r "$TO_DIR" ]] || die "TO_DIR ($TO_DIR) is not readable"
[[ -w "$TO_DIR" ]] || die "TO_DIR ($TO_DIR) is not writable"
[[ -d "$TO_DIR" ]] || die "TO_DIR ($TO_DIR) is not a directory"

log "TO_DIR is $TO_DIR and is a rw directory"

	# even if it's a directory, let's make sure we can get into it
cd "$FROM_DIR" || die "Can't chdir to $FROM_DIR"

	# OK, now we are going to look for JUST the directories INSIDE
	# the TO_DIR directory, so see the last one numbered
	# sed gets rid of the path information and egrep tries
	# to make sure we are only looking at folders which have numbers
	# not letters, punctuation, control characters, or spaces
	# sort -n makes sure that '10' doesn't come between '1' and '2'
	# 'tail -1' grabs the very last one
NUMBER=$(command ls -1d $TO_DIR/*(/) |\
				 sed 's#.*/##' |\
				 egrep -v "[[:alpha:]]|[[:punct:]]|[[:cntrl:]]|[[:space:]]" |\
				 sort -n | tail -1)

	# if we didn't get anything, then assume we should start at zero
[[ "$NUMBER" == "" ]] && NUMBER=0

	# so now that we know what the LAST number was, we want to get the NEXT one
	# so we add one.
((NUMBER++))

log "NUMBER is $NUMBER"


##
#
# Ok, here's our first semi-ugly hack.
# Dropbox will create the folder before it puts any content in it
# Hazel (or launchd or folder actions) will spring into action
# almost immediately.
# BUT we may need to wait for the image to download, especially if
# we are using large images
# SO we are willing to wait if we don't find an image right away.
# How long? Well that is up to you, but I started
# "Check every 5 seconds for a maximum of 10 tries before giving up"


COUNT="0"
MAXCOUNT="10"

while [ "$COUNT" -le "$MAXCOUNT" ]
do

		# Remember we are inside $FROM_DIR and we are looking for files
		# which end in ether JPG or PNG
		# NOTE: This is only designed to handle ONE image per email
		# because that's all I ever send.
		# POTENTIAL BUG: all this does it ensure there is an image file
		# present, it does not necessarily mean that the image has finished
		# downloading
	IMAGE=`command ls -1 | egrep -i '\.(jpg|png)$' | tail -1`

	[[ "$IMAGE" != "" ]] && break

	log "No image found in $PWD, sleeping 15"
	sleep 15

	# increment counter
	((COUNT++))

done

	# If we get here and the IMAGE variable is empty, give up
[[ "$IMAGE" == "" ]] && die "No image found in $FROM_DIR after $MAXCOUNT attempts"

log "IMAGE is $IMAGE"

		# get the extension of the file (JPG or PNG) and make it lowercase
	EXT="`echo $IMAGE:e | tr '[A-Z]' '[a-z]'`"

		# this is what we are going to call the image once it is renamed
		# "photo.PNG" will change to "13.png" or some such
	IMG_NAME="$NUMBER.$EXT"

		# DEPENDENCY: `brew install jhead`
		# this will fix all your "WHY IS THAT ROTATED THAT WAY IN MOBILE SAFARI BUT NOT REGULAR SAFARI?!" woes
		# TRUST ME. You want this. (Yes, I tried 'sips')
	jhead -autorot "$IMAGE"


	#########|#########|#########|#########|#########|#########|#########|#########
	#
	# THIS IS WHERE WE MOVE THE FILE.
	#

	mv -n "$IMAGE" "$TO_DIR/$IMG_NAME" || die "Failed to rename $IMAGE to $TO_DIR/$IMG_NAME"

	log "$IMAGE changed to $TO_DIR/$IMG_NAME (at $URL_PREFIX/$IMG_NAME)"

	#########|#########|#########|#########|#########|#########|#########|#########
	##
	## !!! NOTE !!! We are re-defining a variable here !!! ##
	## NOW we re-define the IMAGE variable to the new path ##
	## We will save OLD_IMAGE in case we need it
	##
	OLD_IMAGE="$IMAGE"
	IMAGE="$TO_DIR/$IMG_NAME"


	# Now the accompanying txt file, if any
	# There may not be a text file, if the email did not have a body to go with it.

	# we are still in FROM_DIR and now we are looking for an file which ends with .txt
	# note that if we find more than one we'll use the last one (alphabetically)
TXT=`command ls -1 | egrep -i '\.txt$' | tail -1`

log "TXT is $TXT"

DIR_NAME=""

if [[ "$TXT" != "" ]]
then

	# We will use the filename of the text file as the <title> and <h1> of the web page
	TITLE="$TXT:t:r"

	log "Title is $TITLE"

	# extract the Creation Date information from the file.
	# It will be in UTC
	CDATE_UTC=$(mdls "$IMAGE" | awk -F' ' '/kMDItemContentCreationDate/{print $3" "$4}')

	log "CDATE_UTC: $CDATE_UTC"

	# Now convert that date/time into 'seconds since epoch'
	CDATE_EPOCH=$(TZ=UTC strftime -r "%Y-%m-%d %H:%M:%S" "$CDATE_UTC")

	log "CDATE_EPOCH: $CDATE_EPOCH"

	# Now convert that 'seconds since epoch' to local time
	CDATE_LOCAL=$(strftime "%Y/%m/%d %-I:%M:%S %p %Z" "$CDATE_EPOCH" )

	log "CDATE_LOCAL: $CDATE_LOCAL"



		# get the width x height
		# Note that we only need this if there's going to be a web page
	SIZE=(`sips --getProperty pixelWidth --getProperty pixelHeight "$IMAGE" | awk -F' ' '/pixel/{print $NF}' `)

	log "SIZE is $SIZE"

	WIDTH="$SIZE[1]"

	log "WIDTH is $WIDTH"

	HEIGHT="$SIZE[2]"

	log "HEIGHT is $HEIGHT."



	# We are going to save the text to a sub-directory
	# where the image was stored $TO_DIR
	# SO, if the image was named /some/path/here/17.jpg then we will use /some/path/here/17/ for the directory
	# we want. We will put an 'index.html' in that directory which means that anyone who goes to that directory
	# will get the contents of the index.html without having to put the index.html
	# (Sort of like leaving the www. of of a website URL.)
	DIR_NAME="$TO_DIR/$NUMBER"

	log "DIR_NAME is $DIR_NAME"

	# We're going to create that directory
	mkdir -p "$DIR_NAME" || die "Failed to create DIR_NAME at $DIR_NAME"

# Now we're going to create a little MultiMarkdown file
# based on the text file we found.
# We are going to add a Title: and Date: to the metadata
# as well as CSS file in case we decide we need to style things later.

# I don't know what the best thing to do is about an ALT tag. I thought about leaving it blank,
# but ultimately decided that I'd rather make sure that someone could tell there was an image there
# even if they couldn't see it.




#########|#########|#########|#########|#########|#########|#########|#########
# DON'T PUT ANYTHING ELSE BETWEEN THESE LINES AND DO NOT INDENT THIS
(echo "Title: $TITLE
Date: "$CDATE_LOCAL"
CSS: http://i.luo.ma/.i.css

<figure>
<figcaption>${TITLE}</figcaption>
<a href=\"../$IMG_NAME\"><img style=\"max-width:100%; height: auto;\" width=${WIDTH} height=${HEIGHT} src=\"../$IMG_NAME\" border=1 alt='[image]' /></a>
</figure>

" && \
cat "${TXT}" && \
echo "


<p id='footer'>$CDATE_LOCAL</p>
")      >    "${DIR_NAME}/index.mmd"

# END OF BLOCK
#########|#########|#########|#########|#########|#########|#########|#########


		# DEPENDENCY: `brew install multimarkdown`
		# I am using version 3.5
		# I have also told it to support footnotes and "smart" quotes
		# and process HTML inside Markdown
		# the output file will be `index.html` and the sources file is `index.mmd` which we just created

	log "Running multimarkdown on ${DIR_NAME}/index.mmd to create ${DIR_NAME}/index.html"

	multimarkdown --to=html --notes --smart --process-html --output="${DIR_NAME}/index.html" "${DIR_NAME}/index.mmd"

		# once we have processed the text file, stick it in the trash

	log "moving $TXT to $DIR_NAME/"
	mv "$TXT" "$DIR_NAME/"

fi # IF a text file was found to do with the image

	# delete the .DS_Store file if it exists
	# because it will prevent rmdir from working
rm -f "$FROM_DIR/.DS_Store"



### OK, so now you have everything that you need
# NOW we try to rsync it to the server
# and we need to know how many times to try.
# Again, I say, go with 10. If it hasn't finished after 10, it probably won't
COUNT="0"
MAXCOUNT="10"


cd "$TO_DIR" || die "Failed to chdir to $TO_DIR"

while [ "$COUNT" -le "$MAXCOUNT" ]
do
	log "rsync count is $COUNT. Syncing $IMAGE and $DIR_NAME"

	rsync --rsh=ssh --recursive --compress "$IMAGE:t" ${DIR_NAME} ${REMOTE_USERNAME}@${REMOTE_SERVER}:${REMOTE_DIRECTORY}/

	EXIT="$?"

	if [[ "$EXIT" = "0" ]]
	then

		if [[ "$TXT" == "" ]]
		then
				# there was no text, just a picture
				# so just send me that URL
			log "texting $URL_PREFIX/$IMG_NAME"
			textme.sh "$URL_PREFIX/$IMG_NAME"

			exit
		else
				# There WAS text with the picture
				# so give me the URL for the image and the page

			log "texting $URL_PREFIX/$IMG_NAME and $URL_PREFIX/$DIR_NAME"

# Don't Indent
textme.sh "$URL_PREFIX/$IMAGE:t
$URL_PREFIX/$DIR_NAME:t"
# don't indent

			exit

		fi

	fi



	# IF we get here, then rsync failed, and we need to increment the counter
	# and try again.
	((COUNT++))

done

log "$NAME: We failed to rsync the local directory $TO_DIR to the remote directory called $REMOTE_DIRECTORY on the server called $REMOTE_SERVER"

# we'll probably want to see this log later, so reveal it in Finder now
open -R "$LOG"

exit 1
#
##### ---FOOTER --- #####
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2012-04-09
# Link:	http://bin.luo.ma/
# MAKE_PUBLIC:
#
#EOF
