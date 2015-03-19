#!/usr/bin/ruby

=begin Strikingly-Interview
  This is my client side algorithm for the Hangman game
  Date: 13th March, 2015
  Author: Stéphane Juban <stephane.juban@gmail.com>
=end

require 'uri'
require 'net/http'
require 'rubygems'
require 'json'
require 'logger'


if ARGV.length != 2
    abort "\nError: The project takes two arguments : DEBUG_LEVEL[INFO/DEBUG] PERFECT_MODE[ON/OFF]\n\n"
end

# Get the log level from command line (default = INFO)
log_level = ARGV[0]
# Do we want to find all the words ?
perfect = ARGV[1]

# Game informations
@playerId = "your_email@example.com"
@URL = "URL_FROM_STRIKINGLY_TEAM"
@sessionId = String.new
@numberOfWordsToGuess = 0
@numberOfGuessAllowedForEachWord = 0
@totalWordCount = 0
@correctWordCount = 0
@totalWrongGuessCount = 0
@score = 0
@wrongGuessCountOfCurrentWord = 0
@word_to_guess = String.new
@bestScoreWrongGuessCount = 0


# Global variables
@best_score_file = "your_best_score_file.txt"
@dictionary_file = "your_dictionary_file.txt"
@letters_used = Array.new
@potential_words = Array.new
@words_found = Array.new
@words_failed = Array.new
@out_of_guess = 0
@no_word_found = 0
@uri = URI(@URL)
@req = Net::HTTP::Post.new @uri.path
@logger = Logger.new(STDOUT)
@perfect_game = false

# Set the log level
case perfect
  when "ON"
    @perfect_game = true
  else
    perfect = "OFF"
    @perfect_game = false
end


# Do we accept errors ?
case log_level
  when "DEBUG"
    @logger.level = Logger::DEBUG
  else
    @logger.level = Logger::INFO
end


# Initialize potential_words for the first iteration
@potential_words << "A"


# Retrieve the best score made so far
best_score = 0
score_line = File.open(@best_score_file, &:readline)
best_score = JSON.parse(score_line)["data"]["score"]
score_data = JSON.parse(score_line)["data"]["datetime"]
@bestScoreWrongGuessCount = JSON.parse(score_line)["data"]["totalWrongGuessCount"]

# Bufferize the dictionary
@dictionary = IO.readlines(@dictionary_file)



@logger.info("")
@logger.info("Welcome to the client side of the Hangman game from Strikingly.")
@logger.info("")
@logger.info("-----------------------------------------------------------------")
@logger.info("                        GAME INFORMATIONS                        ")
@logger.info("                        -----------------                        ")
@logger.info("Best score : #{best_score} the #{score_data}.")
@logger.info("Dictionary : #{@dictionary.length.to_s} words. That's huge isn't it ?!")
@logger.info("Perfect mode is #{perfect}.")
@logger.info("-----------------------------------------------------------------")
@logger.info("")





################################################################################
#########################           FUNCTIONS          #########################
################################################################################

# Function to ask if we send the final result
def submit_result?
  while true
    puts "Do you want to submit this result? [y/n]: "
    case STDIN.gets.chomp
      when 'Y', 'y', 'yes'
        return true
      when /\A[nN]o?\Z/ #n or no
        return false 
    end
  end
end


# Function that return a letter according to the word we give it to her
def MakeAGuess(word)
  
  # Function which compare a line from the dictionary and the word to guess with the letters we already used
  def compare(line, word)
		for i in 0...line.length
			if (line[i] != word[i] && word[i] !='*')
				return false
			end
			if (word[i] == "*" && (@letters_used.include? line[i]))
				return false
			end
		end
		return true
  end
	
	
  # Get the word length
  word_length = word.length
  
  @potential_words.clear
  
  # Get all the potential words from the dictionary
  @dictionary.each do |line|
    line.chomp!
    
    # First of all, filter by word's length
    if line.length == word_length
      
      # Do we already make a guess ? If not, take all the words
      if @letters_used.length > 0
        
        # Is the line from dictionary a potential word ?
        if compare(line.strip.upcase, word) == true
          @potential_words << line.strip.upcase
        end
        
      else
        @potential_words << line.strip.upcase
      end
      
    end
    
  end
  
  
  @logger.debug("We found #{@potential_words.length.to_s} potential words.")
  
  # Record for statistics if we ran out of word
  if @potential_words.empty?
    @no_word_found += 1
  end
  
  # Find the number of occurences of letters for those potential words
  global_letters_count = Hash.new(0)
  #Create a hash table only for the current word to not count a letter twice
  local_letters_count = Hash.new(0)
  
  # For each word, count every letter
  @potential_words.each do |w|
    # Count letter from the word
    w.each_char do |char|
      local_letters_count[char] = 1
    end
    # Increase the global counter for every letters found
    local_letters_count.each do |k, v|
      global_letters_count[k] += v
    end
    
    # Clear the hash for the next word
    local_letters_count.clear
  end
  
  
  # Sort the hash by max value to get the most used letter
  found = false
  letter = ""
  Hash[global_letters_count.sort_by{|k, v| v}.reverse].each do |hash_letter|
    if found == false
      
      # If we already made guesses for this word
      if @letters_used.length > 0
        
        # Pick the letter only if we doesn't already used it
        unless @letters_used.include? hash_letter[0]
          found = true
          letter = hash_letter[0]
        end
        
      else
        found = true
        letter = hash_letter[0]
      end
      
    end
  end
  
  @logger.debug("We found that the most used letter (after our previous guess) is : #{letter}")
  
  # Make a guess according to this count
  @letters_used << letter
  return letter
  
end


# Function sending API calls
def SendAPICall(action, letter=nil)
  
  if action == 'startGame'
    @logger.info("Let's start the game!")
    @req.body = {:playerId => @playerId, :action => action}.to_json
  elsif letter.nil?
    @logger.info("#{action} sent.")
    @logger.info("")
    @req.body = {:sessionId => @sessionId, :action => action}.to_json
  else
    @logger.info("Letter : #{letter}")
    @req.body = {:sessionId => @sessionId, :action => action, :guess => letter}.to_json
  end

  res = Net::HTTP.start(@uri.host, @uri.port, :use_ssl => true) do |http|
    http.request @req
  end
  
  @logger.debug(res.body)
  
  server_response = JSON.parse(res.body)
  
  if action == 'startGame'
    @sessionId = server_response["sessionId"]
    @numberOfWordsToGuess = server_response["data"]["numberOfWordsToGuess"]
    @numberOfGuessAllowedForEachWord = server_response["data"]["numberOfGuessAllowedForEachWord"]
  elsif action == 'getResult'
    @totalWordCount = server_response["data"]["totalWordCount"]
    @correctWordCount = server_response["data"]["correctWordCount"]
    @totalWrongGuessCount = server_response["data"]["totalWrongGuessCount"]
    @score = server_response["data"]["score"]
  elsif action == 'guessWord' or action == 'nextWord'
    @word_to_guess = server_response["data"]["word"]
    @totalWordCount = server_response["data"]["totalWordCount"]
    @wrongGuessCountOfCurrentWord = server_response["data"]["wrongGuessCountOfCurrentWord"]
  elsif action == 'submitResult'
    puts res.body
    return res.body
  end
  
end





################################################################################
###########################           GAME          ############################
################################################################################

# Start the game and store the informations
SendAPICall('startGame')


# Loop while the game is ON
while @totalWordCount <= @numberOfWordsToGuess do

  # Do we ran out of guesses or the word is maybe entirely found or no word in our dictionary match the pattern ?
  if @wrongGuessCountOfCurrentWord >= @numberOfGuessAllowedForEachWord or (@word_to_guess =~ /\*/).nil? or @potential_words.empty?
    
    # Record the word for informations purpose
    @words_found << @word_to_guess.dup
    
    # Record the total amount of wrong guesses
    @totalWrongGuessCount += @wrongGuessCountOfCurrentWord
    
    # Is it the last word ?
    if @totalWordCount >= @numberOfWordsToGuess
      # Break the while loop
      @totalWordCount += 1
    else
      # Do we ran out of guesses ?
      if @wrongGuessCountOfCurrentWord >= @numberOfGuessAllowedForEachWord
        @out_of_guess += 1
      end
      
      # Clear the variables for the next word
      @letters_used.clear
      @potential_words << "A"
      
      # Do we want a perfect game ?
      if ( (@out_of_guess + @no_word_found) > 0 or (@totalWrongGuessCount > @bestScoreWrongGuessCount) ) and @perfect_game
        
        # Record the word that we failed for informations purpose
        @words_failed << @word_to_guess.dup
        
        # Reset variables
        @out_of_guess = 0
        @no_word_found = 0
        @totalWrongGuessCount = 0
        @wrongGuessCountOfCurrentWord = 0
        @word_to_guess.clear
        @words_found.clear
        
        
        
        @logger.info("")
        @logger.info("")
        @logger.info("Starting a new game...")
        @logger.info("-----------------------------------------------------------------")
        @logger.info("")
        @logger.info("List of word we failed to find so far :")
        @logger.info(@words_failed)
        @logger.info("")
        @logger.info("-----------------------------------------------------------------")
        
        # Start a new game
        SendAPICall('startGame')
      else
        # Ask for the next word to guess
        SendAPICall('nextWord')
      end
      
      @logger.info("-----------------------------------------------------------------")
      @logger.info("This is the word n°#{@totalWordCount}. We miss #{@out_of_guess + @no_word_found} word(s) and made #{@totalWrongGuessCount} wrong guesses so far.")
    end
  
  # Else, we can make a guess for the word  
  else
    guess_letter = MakeAGuess(@word_to_guess)

    SendAPICall('guessWord', guess_letter)
    
    @logger.info("Word to guess : #{@word_to_guess} | Wrong guess : #{@wrongGuessCountOfCurrentWord}")
  end
    
end



@logger.info("")
@logger.info("-----------------------------------------------------------------")
@logger.info("Asking for the result...")

SendAPICall('getResult')

if @score > best_score
  @logger.info("Good job, you beat the best score!")
end

@logger.info("Your score is #{@score}!!! You found #{@correctWordCount}/#{@totalWordCount} and made #{@totalWrongGuessCount} wrong guesses.")




if submit_result?
  server_response = SendAPICall('submitResult')
  
  File.open(@best_score_file, 'w') do |file|
    file.write(server_response)
    file.puts @string
    file.write("------------------------------")
    file.write("We ran out of guess #{@out_of_guess} time(s)")
    file.puts @string
    file.write("------------------------------")
    file.write("We did not find the word in our dictionary #{@no_word_found} time(s)")
    file.puts @string
    file.write("------------------------------")
    file.write("Here is the list of words :")
    file.puts @string
    @words_found.each do |word|
      file.write(word)
    end
    file.puts @string
  end
end


@logger.debug("Here are the word we guessed :")
@words_found.each do |word|
  @logger.debug(word)
end

@logger.debug("We ran out of guess #{@out_of_guess} time(s).")
@logger.debug("A word was not found on the dictionary #{@no_word_found} time(s).")

@logger.info("")
@logger.info("-----------------------------------------------------------------")
@logger.info("")