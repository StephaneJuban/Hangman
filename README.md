# Strikingly-Interview

This is my solution to the Hangman challenge from [Strikingly](http://en.wikipedia.org/wiki/Hangman_(game)). So far, my best score with this algorithm is 1414 (80/80 words found with 186 errors).

## Usage

./strikingly-interview.rb DEBUG_LEVEL PERFECT_MODE

## Options

### DEBUG_LEVEL
The default debug level is INFO. You can turn it to DEBUG for more log.

### PERFECT_MODE
The default perfect mode is OFF. If you want the program to found all the words without any mistake and with fewer errors than the actual best score you must turn it ON.
If the program miss a word or if the number of errors from the best score is exceeded, it will restart a game session automatically.

## Contributing

1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request :D

## License

MIT