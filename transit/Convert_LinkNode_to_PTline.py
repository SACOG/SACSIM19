#--------------------------------
# Name: Convert_LinkNode_to_PT_2016.py
# Purpose: Take text file of transit nodes and text file of transit line-level data
# and merge them to make Cube PT line txt file.
#          
#           
# Author: Yanmei Ou
# Last Updated: 02/19/2019
# Updated by: Darren Conly
# Copyright:   (c) SACOG
# Python Version: 3+
#--------------------------------

import os

inputDir = r'Q:\SACSIM23\Network\Cube\TransitLIN\2007 TAZs\transit_linenode'
inputLink = '2016_tranline_lines.txt'
inputNode = '2016_tranline_nodes_TAZ21.txt'

outputTranLine = '2016_tranline_TAZ21.lin'

#=================BEGIN SCRIPT=======================

# output line file
f_out = open(os.path.join(inputDir,outputTranLine), 'w')

f_in_link = open(os.path.join(inputDir,inputLink),'r')
####f_out_link.write('NAME,TIMEFAC,ONEWAY,MODE,OPERATOR,COLOR,CIRCULAR,HEADWAY1,HEADWAY2,HEADWAY3,HEADWAY4,HEADWAY5'+"\n")
###NAME,TIMEFAC,ONEWAY,MODE,OPERATOR,COLOR,CIRCULAR,TF1,TF2,TF3,TF4,HEADWAY1,HEADWAY2,HEADWAY3,HEADWAY4,HEADWAY5
f_in_node = open(os.path.join(inputDir,inputNode),'r')
###f_out_node.write('NAME,NODE,SEQ,STOP,TF'+"\n")

aNodeDic = {} #structure: {'LINENAME':['LINENAME','NODE','SEQ','STOP','TF']}
aList = []
#node,seq,stop,tf


#read node.txt into aNodeDic
#key is line name, value is list of line's nodes
lines_node = f_in_node.readlines()
for aLine in lines_node:
	aLi = aLine.strip() #'LINENAME,NODE,SEQ,STOP,TF'
	aWord = aLi.split(',') #['LINENAME','NODE','SEQ','STOP','TF']
	aLineName = aWord[0] #'LINENAME'
	if aLineName != 'NAME': #skip first line
		if aNodeDic.get(aLineName) != None:
			aList = aNodeDic[aLineName]
			aList.append(aLi) #['LINENAME,NODE,SEQ,STOP,TF', 'LINENAME2,NODE2,SEQ2,STOP2,TF2']
			aNodeDic[aLineName] = aList
		else:
			aList = [aLi] # ['LINENAME,NODE,SEQ,STOP,TF']
			aNodeDic[aLineName] = aList # aNodeDic['LINENAME'] = ['LINENAME,NODE,SEQ,STOP,TF']
f_in_node.close()
		
aSpace6 = '     '
aSpace2 = ' '
aDeli = ','
aQuote = '"'
L = 1

nameDic = {}
lines_link = f_in_link.readlines()

#reads line file into nameDic, with line_name:<all line attribs in row as string>
for aLine in lines_link:
	if not len(aLine) == 0 and L > 1: 
		#print aLine
		aLi = aLine.strip()
		aWordList = aLi.split(',')
		aLineName = aWordList[0]
		nameDic[aLineName] = aLine
	L = L + 1
nameList = list(nameDic.keys())
nameList.sort() #sort by line name
###NAME,TIMEFAC,ONEWAY,MODE,OPERATOR,COLOR,CIRCULAR,TF1,TF2,TF3,TF4,HEADWAY1,HEADWAY2,HEADWAY3,HEADWAY4,HEADWAY5


L = 1
for aName in nameList:
	#print str(i)
	#get all attributes for each line in a list
	aLine = nameDic[aName]
	if not len(aLine) == 0: 
		aLi = aLine.strip()
		aWordList = aLi.split(',')
		aLineName = aWordList[0] #line name
		aTF_Line = aWordList[1]
		aOneway = aWordList[2]
		aMode = aWordList[3]
		aOperator = aWordList[4]
		aColor = aWordList[5]
		aCircular = aWordList[6]
		aTF1 = aWordList[7]
		aTF2 = aWordList[8]
		aTF3 = aWordList[9]
		aTF4 = aWordList[10]
		aTF5 = aWordList[11]
		aHead_1 = aWordList[12]
		aHead_2 = aWordList[13]
		aHead_3 = aWordList[14]
		aHead_4 = aWordList[15]
		aHead_5 = aWordList[16]
		
		if aNodeDic.get(aLineName) != None:
			aTFdic = {}
			aList = aNodeDic[aLineName] #list of line's attributes from the node.txt input
			
			for aWord in aList:
				aWordList = aWord.split(',') #split out the node attribs into a list
				aNodeID = aWordList[1] #node id
				aSeq = aWordList[2] #node sequence
				aStop = aWordList[3] #is a stop
				aTF = aWordList[4] #time factor for node
				if aTF != '0': #if time factor is not zero
					if aTFdic.get(aTF) is None: #then if tfdic doesn't have that TF
						#print aLineName+' '+aNodeID+' '+aTF+' '+aSeq
						aTFdic[aTF] = (str(aSeq)) #then in the tfdic, the time factor
												#corresponding value is the sequence
			
			aNodeList = [] #each line will get a list of its nodes, following
							#the conditions below
			for aWord2 in aList:
				aWordList2 = aWord2.split(',')
				aNodeID = aWordList2[1]
				aSeq = aWordList2[2]
				aStop = aWordList2[3]
				aTF = aWordList2[4]
				
				if (aSeq == '0' and aStop == 'Y'):
					aNode = 'N='+aNodeID #if first node in line and is stop, prefix with "N="
				elif(aSeq == '0' and aStop == 'N'):
					aNode = 'N=-'+aNodeID #if first node in line and not stop, prefix with "N=-"
				
				#if not first node, then if also not stop, put '-' in front of nodeID
				#'-' prefix means it's a node but not a stop on the line
				elif (aSeq != '0' and aStop == 'Y' and aTF == '0'):
					aNode = aNodeID
				elif (aSeq != '0' and aStop == 'N' and aTF == '0'):
					aNode = '-'+aNodeID
					
				#if TF other than 0, then from that node onward the time factor
				#will be that TF value instead of the default TIMEFAC values
				elif (aSeq != '0' and aStop == 'Y' and aTF != '0'):
					#makes sure that it only inserts the 'TF=' tag once.
					aSeqF = aTFdic[aTF]
					if aSeq == aSeqF:
						aNode = 'TF='+aTF+', N='+aNodeID
						#print aLineName+' '+aSeqF+' '+aNode
					else:
						aNode = aNodeID
						
				#same "if TF" condition, but for nodes that are NOT stops
				elif (aSeq != '0' and aStop == 'N' and aTF != '0'):
					aSeqF = aTFdic[aTF]
					if aSeq == aSeqF:
						aNode = 'TF='+aTF+', N=-'+aNodeID
						#print aLineName+' '+aSeqF+' '+aNode
					else:
						aNode = '-'+aNodeID
				aNodeList.append(aNode)
			
			
			NumNodes = len(aNodeList) #count of nodes
			
			#eight nodes on each line of tranline file, this gives count of lines
			#of text taken up by listing the nodes.
			#use the "-2" because the first row of node values only has 2 node values
			NumLines = int((NumNodes-2)/8) 
			
			
			#get the remainder number of nodes; the number of nodes on the last
			#line of text on which nodes are listed
			NumNodesLastLine = (NumNodes-2) % 8
			
			#if aLineName == 'R_2MB':
				#print str(NumNodes)+' '+str(NumLines)+' '+str(NumNodesLastLine)
			
			#for each line, write out stuff to tranline.txt, exactly as formatted for model
			Line1 = 'LINE'+aSpace2+'NAME='+aQuote+aLineName+aQuote+', TIMEFAC[1]='+aTF1+', TIMEFAC[2]='+aTF2+', TIMEFAC[3]='+aTF3+', TIMEFAC[4]='+aTF4+', TIMEFAC[5]='+aTF5+','
			f_out.write(Line1+"\n")
			
			Line2 = aSpace6+'ONEWAY='+aOneway+', MODE='+aMode+', OPERATOR='+aOperator+', COLOR='+aColor+', CIRCULAR='+aCircular+', HEADWAY[1]='+aHead_1+', HEADWAY[2]='+aHead_2+','
			f_out.write(Line2+"\n")
			
			#if > 2 nodes in line, then set comma to start new line for additional rows of nodes. Otherwise end the line.
			if NumNodes > 2:
				Line3 = aSpace6+'HEADWAY[3]='+aHead_3+', HEADWAY[4]='+aHead_4+', HEADWAY[5]='+aHead_5+', '+aNodeList[0]+', '+aNodeList[1]+','
			else:
				Line3 = aSpace6+'HEADWAY[3]='+aHead_3+', HEADWAY[4]='+aHead_4+', HEADWAY[5]='+aHead_5+', '+aNodeList[0]+', '+aNodeList[1]
			
			f_out.write(Line3+"\n")
			
			#write out each line of nodes, separated by comma and space
			for i in range(1,NumLines+1):
				NodeS = i*8-6
				for j in range(NodeS,NodeS+8): #limit to 8 nodes per row
					#if aLineName == 'R_2MB':
						#print aNodeList[52]
					if j == NodeS:
						aLine = aNodeList[j]
					else:
						aLine = aLine+', '+aNodeList[j]
				if (i == NumLines and NumNodesLastLine == 0):
					f_out.write(aSpace6+aLine+"\n")
				else:
					f_out.write(aSpace6+aLine+', '+"\n")
				
			if(NumNodesLastLine>0):
				LastLineS = NumNodes-NumNodesLastLine
				
				for n in range(LastLineS,NumNodes):
					if (n == LastLineS):
						LastLine = aNodeList[n]
					else:
						LastLine = LastLine+', '+aNodeList[n]
				f_out.write(aSpace6+LastLine+"\n")
		
		#if no nodes for a given line, just give it one node N=1
		else:
			Line1 = 'LINE'+aSpace2+'NAME='+aQuote+aLineName+aQuote+', TIMEFAC[1]='+aTF1+', TIMEFAC[2]='+aTF2+', TIMEFAC[3]='+aTF3+', TIMEFAC[4]='+aTF4+', TIMEFAC[5]='+aTF5+','
			f_out.write(Line1+"\n")
			Line2 = aSpace6+'ONEWAY='+aOneway+', MODE='+aMode+', OPERATOR='+aOperator+', COLOR='+aColor+', CIRCULAR='+aCircular+', HEADWAY[1]='+aHead_1+', HEADWAY[2]='+aHead_2+','
			f_out.write(Line2+"\n")
			Line3 = aSpace6+'HEADWAY[3]='+aHead_3+', HEADWAY[4]='+aHead_4+', HEADWAY[5]='+aHead_5+', N=1'
			f_out.write(Line3+"\n")
	L = L + 1				
f_in_link.close()
f_in_node.close()
f_out.close()

print("Success!")