<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="http://www.w3.org/1999/xhtml" version="1.0">

 <xsl:output omit-xml-declaration="no"
             method="xml"
	     indent="yes"
             encoding="utf-8" />
 <xsl:template match="/">
  <html>
   <head>
    <title/>
    <link rel="stylesheet" href="style.css" type="text/css"/>
   </head> 
   <body>
     <xsl:apply-templates select="comment()" mode="prolog" />
     <xsl:apply-templates select="* | processing-instruction()" />
   </body>
  </html> 
 </xsl:template>


<xsl:template match="section|epigraph|annotation|poem">
    <div class="{local-name()}">
        <xsl:apply-templates />
    </div>
</xsl:template>


<xsl:template match="p|empty-line|v|cite|title|subtitle">
    <p class="{local-name()}">
        <xsl:apply-templates />
    </p>
</xsl:template>

<xsl:template match="strong|sub|sup|code">
	<b><xsl:apply-templates /></b>
</xsl:template>

<xsl:template match="emphasis">
    <em><xsl:apply-templates /></em>
</xsl:template>



</xsl:stylesheet>
