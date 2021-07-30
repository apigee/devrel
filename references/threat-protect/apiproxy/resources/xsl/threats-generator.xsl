<?xml version="1.0" encoding="utf-8"?>
<!--
 Copyright 2021 Google LLC
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
      http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
-->
<xsl:stylesheet version="1.0"					
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		extension-element-prefixes="" 							
		exclude-result-prefixes="">
						
	<!-- Define the output as an indented XML content -->
	<!-- The output of this XSL Stylesheet is an XML Threat - so you might take care of it ! -->
	<xsl:output method="xml" indent="yes" encoding="UTF-8"/>
	
	<!-- Variables that contain generic element and attribute names -->
	<xsl:variable name="generic-element-name">elmt_</xsl:variable>
	<xsl:variable name="generic-attribute-name">entry_</xsl:variable>
	
	<!-- Variable that contains the default value for attributes(xml) or object entry(json) (width attack) -->
	<xsl:variable name="generic-attribute-value">value</xsl:variable>
	
	<!-- Variable that contains the default value for namespaces(xml) (width attack) -->
	<xsl:variable name="generic-ns-name">ns_</xsl:variable>
	<xsl:variable name="generic-ns-value">https://example.com/ns</xsl:variable>
	
	<!-- Variable that contains the default name of the tag used to generate array (width attack) -->
	<xsl:variable name="generic-array-name">items</xsl:variable>

<!--+
	|********************************
	|*** Matching Template
	|*** Element: ROOT
	|********************************
	+-->
	<xsl:template match="/">
		
		<!-- Apply templates on the 'DocXMLGenerator' element -->
		<xsl:apply-templates select="DocXMLGenerator"/>

		<!-- Apply templates on the 'DocJSONGenerator' element -->
		<xsl:apply-templates select="DocJSONGenerator"/>
	</xsl:template>
	
<!--+
	|********************************
	|*** Matching Template
	|*** Element: DocXMLGenerator
	|********************************
	+-->
	<xsl:template match="DocXMLGenerator">
		
		<!-- Create the XML Threat... -->
		<XMLThreat>
		    
		    <!-- variables received from the input XML document -->
		    <xsl:variable name="height" select="./NumElements/text()"/> 
			<xsl:variable name="width" select="./NumAttributes/text()"/> 
			<xsl:variable name="depth" select="./ElementDepth/text()"/> 
			<xsl:variable name="length" select="./NumNS/text()"/> 
		    
		    <!-- add the right number of namespaces on the root element (XMLThreat) -->
		    <xsl:call-template name="setNamespaces">
				<xsl:with-param name="aNumNS" select="./NumNS/text()"/>
			</xsl:call-template>
		    
			<!-- Create the threat with the right parameters -->
			<xsl:call-template name="setXMLThreat">
				<xsl:with-param name="aNumElement" select="number($height)"/>
				<xsl:with-param name="aNumAttribute" select="number($width)"/>
				<xsl:with-param name="aElementDepth" select="number($depth) - 2"/>
			</xsl:call-template>
		</XMLThreat>
	</xsl:template>

<!--+
	|********************************
	|*** Matching Template
	|*** Element: DocJSONGenerator
	|********************************
	+-->
	<xsl:template match="DocJSONGenerator">

		<!-- Create the JSON Threat... -->
		<JSONThreat>
		    <!-- variables received from the input XML document -->
		    <xsl:variable name="height" select="./NumElements/text()"/> 
			<xsl:variable name="width" select="./NumAttributes/text()"/> 
			<xsl:variable name="depth" select="./ElementDepth/text()"/> 
			<xsl:variable name="length" select="./NumNS/text()"/>
			
			<!-- if depth equals 0 then we can use 'width' as is -->
			<xsl:variable name="revwidth">
			    <xsl:choose>
			        <xsl:when test="number($depth) &lt;= 0">
			            <xsl:value-of select="$width"/>
			        </xsl:when>
			        <xsl:otherwise>
			            <xsl:value-of select="number($width) - 1"/>
			        </xsl:otherwise>
			    </xsl:choose>
			</xsl:variable>
			
			<!-- if length equals 0 then we can use 'height' as is -->
			<xsl:variable name="revheight">
			    <xsl:choose>
			        <xsl:when test="number($length) &lt;= 0">
			            <xsl:value-of select="$height"/>
			        </xsl:when>
			        <xsl:otherwise>
			            <xsl:value-of select="number($height) - 1"/>
			        </xsl:otherwise>
			    </xsl:choose>
			</xsl:variable>
			
			<!-- add the right number of elements that are used to generate an array -->
		    <xsl:call-template name="setArrayElements">
				<xsl:with-param name="aNumNS" select="$length"/>
			</xsl:call-template>

			<!-- Create the threat with the right parameters -->
			<xsl:call-template name="setXMLThreat">
				<xsl:with-param name="aNumElement" select="number($revheight)"/>
				<xsl:with-param name="aNumAttribute" select="number($revwidth)"/>
				<xsl:with-param name="aElementDepth" select="number($depth) - 3"/>
			</xsl:call-template>
		</JSONThreat>

	</xsl:template>
	
<!--+
	|********************************
	|*** Named Template
	|*** Name: setXMLThreat
	|********************************
	+-->
	<!-- Set the the required XML threats: Width/Size/Depth attacks -->
	<xsl:template name="setXMLThreat">
		<xsl:param name="aNumElement"/>
		<xsl:param name="aNumAttribute"/>
		<xsl:param name="aElementDepth"/>
		
		<!-- Code to be added here... -->
		<xsl:call-template name="setDocumentSizeAttack">
			<xsl:with-param name="aNumElement" select="$aNumElement"/>
			<xsl:with-param name="aNumAttribute" select="$aNumAttribute"/>
			<xsl:with-param name="aElementDepth" select="$aElementDepth"/>
		</xsl:call-template>

	</xsl:template>
	
<!--+
	|********************************
	|*** Named Template
	|*** Name: setDocumentSizeAttack
	|********************************
	+-->
	<!-- Set the the required XML threats: Width/Size/Depth attacks -->
	<xsl:template name="setDocumentSizeAttack">
		<xsl:param name="aNumElement"/>
		<xsl:param name="aNumAttribute"/>
		<xsl:param name="aElementDepth"/>
		<xsl:param name="aIterator" select="1"/>
		
		<xsl:choose>
			<xsl:when test="number($aIterator) &lt;= number($aNumElement)">
				<xsl:element name="{concat($generic-element-name,string($aIterator))}">
					<xsl:call-template name="setDocumentWidthAttack">
						<xsl:with-param name="aNumElement" select="$aNumElement"/>
						<xsl:with-param name="aNumAttribute" select="$aNumAttribute"/>
						<xsl:with-param name="aElementDepth" select="$aElementDepth"/>
					</xsl:call-template>
					<xsl:call-template name="setDocumentDepthAttack">
						<xsl:with-param name="aNumElement" select="$aNumElement"/>
						<xsl:with-param name="aNumAttribute" select="$aNumAttribute"/>
						<xsl:with-param name="aElementDepth" select="$aElementDepth"/>
						<xsl:with-param name="aIterator1" select="number($aIterator)"/>
					</xsl:call-template>
				</xsl:element>
				<xsl:call-template name="setDocumentSizeAttack">
					<xsl:with-param name="aNumElement" select="$aNumElement"/>
					<xsl:with-param name="aNumAttribute" select="$aNumAttribute"/>
					<xsl:with-param name="aElementDepth" select="$aElementDepth"/>
					<xsl:with-param name="aIterator" select="number($aIterator)+1"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise/>
		</xsl:choose>
		
	</xsl:template>
	
<!--+
	|********************************
	|*** Named Template
	|*** Name: setDocumentWidthAttack
	|********************************
	+-->
	<!-- Set the the required XML threats: Width/Size/Depth attacks -->
	<xsl:template name="setDocumentWidthAttack">
		<xsl:param name="aNumElement"/>
		<xsl:param name="aNumAttribute"/>
		<xsl:param name="aElementDepth"/>
		<xsl:param name="aIterator" select="1"/>
		
		<xsl:choose>
			<xsl:when test="number($aIterator) &lt;= number($aNumAttribute)">
				<xsl:attribute name="{concat($generic-attribute-name,string($aIterator))}">
					<xsl:value-of select="$generic-attribute-value"/>
				</xsl:attribute>
				<xsl:call-template name="setDocumentWidthAttack">
					<xsl:with-param name="aNumElement" select="$aNumElement"/>
					<xsl:with-param name="aNumAttribute" select="$aNumAttribute"/>
					<xsl:with-param name="aElementDepth" select="$aElementDepth"/>
					<xsl:with-param name="aIterator" select="number($aIterator)+1"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise/>
		</xsl:choose>
		
	</xsl:template>

<!--+
	|********************************
	|*** Named Template
	|*** Name: setDocumentDepthAttack
	|********************************
	+-->
	<!-- Set the the required XML threats: Width/Size/Depth attacks -->
	<xsl:template name="setDocumentDepthAttack">
		<xsl:param name="aNumElement"/>
		<xsl:param name="aNumAttribute"/>
		<xsl:param name="aElementDepth"/>
		<xsl:param name="aIterator1" select="1"/>
		<xsl:param name="aIterator2" select="1"/>
		
		<xsl:choose>
			<xsl:when test="number($aIterator2) &lt;= number($aElementDepth)">
				<xsl:element name="{concat($generic-element-name,string($aIterator1),'_',string($aIterator2))}">
					<xsl:call-template name="setDocumentWidthAttack">
						<xsl:with-param name="aNumElement" select="$aNumElement"/>
						<xsl:with-param name="aNumAttribute" select="$aNumAttribute"/>
						<xsl:with-param name="aElementDepth" select="$aElementDepth"/>
					</xsl:call-template>
					<xsl:call-template name="setDocumentDepthAttack">
						<xsl:with-param name="aNumElement" select="$aNumElement"/>
						<xsl:with-param name="aNumAttribute" select="$aNumAttribute"/>
						<xsl:with-param name="aElementDepth" select="$aElementDepth"/>
						<xsl:with-param name="aIterator1" select="number($aIterator1)"/>
						<xsl:with-param name="aIterator2" select="number($aIterator2)+1"/>
				</xsl:call-template>
				</xsl:element>
			</xsl:when>
			<xsl:otherwise/>
		</xsl:choose>
		
	</xsl:template>
	
<!--+
	|********************************
	|*** Named Template
	|*** Name: setNamespaces
	|********************************
	+-->
	<!-- Set the the required number of namespaces on the root element (XMLThreat) -->
	<xsl:template name="setNamespaces">
		<xsl:param name="aNumNS"/>
		<xsl:param name="aIterator" select="1"/>
		
		<xsl:choose>
			<xsl:when test="number($aIterator) &lt;= number($aNumNS)">
				<xsl:namespace name="{concat($generic-ns-name,string($aIterator))}" select="$generic-ns-value"/>
				<xsl:call-template name="setNamespaces">
					<xsl:with-param name="aNumNS" select="$aNumNS"/>
					<xsl:with-param name="aIterator" select="number($aIterator)+1"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise/>
		</xsl:choose>
		
	</xsl:template>
	
<!--+
	|********************************
	|*** Named Template
	|*** Name: setArrayElements
	|********************************
	+-->
	<!-- Set the the required number of elements used to generate an array during the XML2JSON mediation -->
	<xsl:template name="setArrayElements">
		<xsl:param name="aNumNS"/>
		<xsl:param name="aIterator" select="1"/>
		
		<xsl:choose>
			<xsl:when test="number($aIterator) &lt;= number($aNumNS)">
				<xsl:element name="{$generic-array-name}"><xsl:value-of select="concat('item_',$aIterator)"/></xsl:element>
				<xsl:call-template name="setArrayElements">
					<xsl:with-param name="aNumNS" select="$aNumNS"/>
					<xsl:with-param name="aIterator" select="number($aIterator)+1"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise/>
		</xsl:choose>
		
	</xsl:template>

</xsl:stylesheet>
