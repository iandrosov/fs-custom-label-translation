/**
 * CustomLabelTranslation utility class support translation labels.
 *
 * Translation helper class custom labels
 * @author Igor Androsov
 * @version 1.0
 */
public with sharing class CustomLabelTranslation {
    private static final String INSTANCE_URL = Url.getSalesforceBaseUrl()
    .toExternalForm();
  private static final String TOOLING_ENDPOINT = '/services/data/v53.0/tooling/query/?q=';
  private static final String TOOLING_LABEL_QUERY = 'Select+id,Name,Value,Language+from+ExternalString';
  private static final String TOOLING_LABEL_TRANSLATION_QUERY = 'Select+Value,Language,ExternalString.Name+from+ExternalStringLocalization';
  private static final String LABEL_WHERE_STRING = '+where+Name+IN+';
  private static final String LABEL_TRANSLATION_WHERE_STRING = '+where+ExternalString.Name+IN+';

  private static List<Records> externalStringRecords = new List<Records>();

    /* DEPERECTED: Method no longer used
  public static String translateLabel(String str) {
    String lang = CAMA_SettingsUtil.getLanguage();
    Map<String, String> mapLbl = getLabelsFromCache(lang);
    String lbl = getTextLabel(str, mapLbl);
    system.debug('## Translated: ' + str + ' - ' + lbl);
    return lbl;
  }
    
  private Map<String, String> getLabelsByLang(String language) {
    Map<String, String> labelMap = getLabelsFromCache(language);
    return labelMap;
  }
*/

  /**
     * sample script  en_US or ja - japanese
     * 
     Map<String, Map<String, String>> customLabelsByLanguage = CAMA_CustomLabelTranslation.getCustomLabelsByLanguage(null);
List<CAMA_Translation__c> trnList = new List<CAMA_Translation__c>();
for(String language: customLabelsByLanguage.keySet()){
   System.debug('language: ' + language);

   Map<String, String> labelMap = customLabelsByLanguage.get(language);

   for(String labelName : labelMap.keySet()){
       System.debug('Custom Label Name: ' + labelName);
       System.debug('Custom Label Value: ' + labelMap.get(labelName));
       CAMA_Translation__c  trn = new CAMA_Translation__c();
       trn.Language__c = language;
       trn.Label__c = labelName;
       trn.Value__c = labelMap.get(labelName);
       trnList.add(trn);
   }
   
}
insert trnList;

If we only want to return specific custom label translations then we can pass a list of custom label names instead of the null value passed above. See example below:
List<String> customLabelNames = new List<String>{'Sample_Label', 'Visualforce_Header_Label'};
Map<String, Map<String, String>> customLabelsByLanguage = CustomLabelTranslation.getCustomLabelsByLanguage(customLabelNames);
     */

  /**
   * @param customLabelNames The names of custom labels to retrieve
   *                         Pass null to retrieve all the custom labels and translations in the org
   *                         Retrieving all labels will be limited by the Apex max Heap size so beware if you have a lot of labels
   *
   * @return a Map from language -> label name -> label value
   *          Retrieves all languages available in the org. This could be enhanced to only retrieve certain languages
   *
   * e.g. en_US -> {'label1Name' -> 'this is a label', 'label2Name' -> 'another label'},
   *      fr_CA -> {'label1Name' -> 'Le label'}
   */
  public static Map<String, Map<String, String>> getCustomLabelsByLanguage(
    List<String> customLabelNames
  ) {
    String externalStringQuery = getExternalStringQuery(customLabelNames);
    String externalStringLocalizationQuery = getExternalStringLocalizationQuery(
      customLabelNames
    );

    makeCustomLabelCallout(externalStringQuery, null);
    makeCustomLabelCallout(externalStringLocalizationQuery, null);
    Map<String, Map<String, String>> languageToLabels = mapCustomLabelsByLanguage(
      externalStringRecords
    );
    return languageToLabels;
  }

  /**
   * @param customLabelNames when provided, only the appropriate custom labels are retrieved
   * @param nextQueryUrl When provided, the makeCustomLabelCallout is recursively called until all labels are retrieved
   */
  public static void makeCustomLabelCallout(String query, String nextQueryUrl) {
    HttpRequest req = new HttpRequest();
    req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
    req.setHeader('Content-Type', 'application/json');

    if (String.isBlank(nextQueryUrl)) {
      req.setEndpoint(query);
    } else {
      req.setEndpoint(INSTANCE_URL + nextQueryUrl);
    }
    req.setMethod('GET');

    Http h = new Http();
    HttpResponse res = h.send(req);
    String strResult = res.getBody();
    System.debug('## JSON LABELS: ' + strResult);
    //if(strResult != null && strResult.length()>0){
    //saveLabels(strResult);
    //}else{
    //    strResult = getLabels();
    //}
    Response response = (Response) JSON.deserialize(strResult, Response.class);
    externalStringRecords.addAll(response.records);
    if (!response.done) {
      makeCustomLabelCallout(null, response.nextRecordsUrl);
    }
  }

  private static String getExternalStringQuery(List<String> customLabelNames) {
    if (customLabelNames != null) {
      return INSTANCE_URL +
        TOOLING_ENDPOINT +
        TOOLING_LABEL_QUERY +
        LABEL_WHERE_STRING +
        formatLabelNamesForQuery(customLabelNames);
    }
    //Retrieve all labels
    return INSTANCE_URL + TOOLING_ENDPOINT + TOOLING_LABEL_QUERY;
  }

  private static String getExternalStringLocalizationQuery(
    List<String> customLabelNames
  ) {
    if (customLabelNames != null) {
      return INSTANCE_URL +
        TOOLING_ENDPOINT +
        TOOLING_LABEL_TRANSLATION_QUERY +
        LABEL_TRANSLATION_WHERE_STRING +
        formatLabelNamesForQuery(customLabelNames);
    }
    //Retrieve all labels
    return INSTANCE_URL + TOOLING_ENDPOINT + TOOLING_LABEL_TRANSLATION_QUERY;
  }

  private static String formatLabelNamesForQuery(
    List<String> customLabelNames
  ) {
    String value = '(';

    for (String s : customLabelNames) {
      value += '\'' + s + '\'' + ',';
    }

    if (String.isNotBlank(value)) {
      value = value.removeEnd(',');
      value += ')';
    }
    return value;
  }
    // Temp save labels in setting as JSON
    private static void saveLabels(String str) {
        List<CAMA_Settings__c> conf = [
          SELECT Id, Name, JSON_Labels__c
          FROM CAMA_Settings__c
        ];
        if (conf.size() > 0) {
          conf[0].JSON_Labels__c = str;
          update conf;
        }
      }
      private static String getLabels() {
        String str = '';
        List<CAMA_Settings__c> conf = [
          SELECT Id, Name, JSON_Labels__c
          FROM CAMA_Settings__c
        ];
        if (conf.size() > 0) {
          str = conf[0].JSON_Labels__c;
        }
        return str;
      }
    
  public static Map<String, Map<String, String>> mapCustomLabelsByLanguage(
    List<Records> customLabelRecords
  ) {
    Map<String, Map<String, String>> languageToLabelsMap = new Map<String, Map<String, String>>();

    for (Records record : customLabelRecords) {
      if (String.isNotBlank(record.Language)) {
        Map<String, String> customLabels = languageToLabelsMap.get(
          record.Language
        );
        if (customLabels == null)
          customLabels = new Map<String, String>();

        //Handle scenario where custom label name is coming from lookup to ExternalString
        if (record?.ExternalString?.Name != null) {
          customLabels.put(record.ExternalString.Name, record.Value);
        } else {
          customLabels.put(record.Name, record.Value);
        }
        languageToLabelsMap.put(record.Language, customLabels);
      }
    }

    return languageToLabelsMap;
  }


  public class Response {
    public Integer size;
    public Integer totalSize;
    public Boolean done;
    public String queryLocator;
    public String nextRecordsUrl;
    public String entityTypeName;
    public List<Records> records;
  }

  public class Attributes {
    public String type;
    public String url;
  }

  public class ExternalString {
    public Attributes attributes;
    public String Name;
  }

  public class Records {
    public Attributes attributes;
    public String Id;
    public String Name;
    public String Language;
    public String Value;
    public ExternalString ExternalString;
  }

}