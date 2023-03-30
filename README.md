# How to run the Server

1. Installing dependencies
	First run `npm i` to ensure that all the node depenedencies are installed.
2. Install truffle globally
	Run `npm i -g truffle`
3. Ensure that Ganache is running
	I am using a Ganache GUI server. It runs as soon as I open the GUI. Also confirm that the port number is 7545.
4. Build the Contract
	run `truffle migrate`. It should compile and deploy the contract. A build folder will be generated and populated. If theres any issue with compilation, run `truffle compile` and debug from there. If theres any issue with deployment, verify that the ganache instance is running.
5. Run the server
	Run `node server.js` and check if it connects to the ganache instance. This is where it is currently failing
