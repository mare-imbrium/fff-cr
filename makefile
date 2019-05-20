SRC=src/*.cr

fff: $(SRC)
	time crystal build src/fff.cr
