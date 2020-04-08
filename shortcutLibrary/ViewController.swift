//
//  ViewController.swift
//  shortcutLibrary
//
//  Created by hrdkdh on 2020/03/21.
//  Copyright © 2020 hrdkdh. All rights reserved.
//

import UIKit
import Realm
import RealmSwift
import GoogleMobileAds

//Setting class에서 obj추가되면 반드시 아래 배열에도 추가할 것!
let settingFieldList=["powerpoint", "excel", "word", "hangul", "chrome", "windows"]
let settingFieldListHangul=["파워포인트", "엑셀", "워드", "아래아한글", "크롬", "윈도우"]
let csvFileName="200407"
let csvFileType="csv"

//테스트 광고 아이디
//let adUnitId1 = "ca-app-pub-3940256099942544/2934735716"
//let adUnitId2 = "ca-app-pub-3940256099942544/4411468910" //전면광고
//let adUnitId3 = "ca-app-pub-3940256099942544/2934735716"
//let adUnitId4 = "ca-app-pub-3940256099942544/2934735716"

//스크린샷용 가짜 광고 아이디
let adUnitId1 = "ca-app-pub"
let adUnitId2 = "ca-app-pub"
let adUnitId3 = "ca-app-pub"
let adUnitId4 = "ca-app-pub"

//진짜 광고 아이디
//let adUnitId1 = "ca-app-pub-4567650475621525/8491751157"
//let adUnitId2 = "ca-app-pub-4567650475621525/5082951194"
//let adUnitId3 = "ca-app-pub-4567650475621525/7527838053"
//let adUnitId4 = "ca-app-pub-4567650475621525/8824290620"


var savedFavoriteData : Array<[String : String]> = []
var searchTableReloadCheck=false

//realm 객체 생성 클래스
class Shortcut : Object {
    @objc dynamic var pk : Int = 0
    @objc dynamic var category : String = ""
    @objc dynamic var category_hangul : String = ""
    @objc dynamic var ctrl : String = ""
    @objc dynamic var alt : String = ""
    @objc dynamic var shift : String = ""
    @objc dynamic var key1 : String = ""
    @objc dynamic var key2 : String = ""
    @objc dynamic var key3 : String = ""
    @objc dynamic var key4 : String = ""
    @objc dynamic var commandString : String = ""
    @objc dynamic var searchString : String = ""
    @objc dynamic var score : Int = 0
    @objc dynamic var favorite : Int = 0
    @objc dynamic var commandKeyStr : String = ""
}

class Setting : Object {
    //아래에 변수가 추가될 경우 setting 클래스에서도 변수 리스트에 추가해 줘야 함!!!
    @objc dynamic var powerpoint : Bool = true
    @objc dynamic var excel : Bool = true
    @objc dynamic var word : Bool = true
    @objc dynamic var hangul : Bool = true
    @objc dynamic var chrome : Bool = true
    @objc dynamic var windows : Bool = true
}

//DB초기화 및 업데이트 클래스 200326 완료, 0238 수정
class setupDatabase {
    
    func initDB() {
        //이미 생성된 DB파일이 존재하는지 체크
        let checkDBVersionSync=checkFileExist(checkFileName: csvFileName, checkFileType: "txt")
        if checkDBVersionSync {
            print("DB is newest")
        } else {
            print("DB is old")
            print("DB파일을 새롭게 생성합니다...")
            removeDB()
            guard let orgDbString = readDataFromCSV(fileName: csvFileName, fileType: csvFileType) else { return }
            //print(String(orgDbString!))
            let orgDbStringCleaned=cleanRows(file: orgDbString)
            let orgArr = getArrFromCsvString(data: orgDbStringCleaned)
            var index : Int = 0
            var thisPk : Int = 0
            var thisScore : Int = 0
            var thisFavorite : Int = 0
            for row in orgArr {
                index+=1
                if Int(row[12]) != nil { thisScore=Int(row[12])! }
                if Int(row[13]) != nil { thisFavorite=Int(row[13])! }

                let rowList=[row[3],row[4],row[5],row[6],row[7],row[8],row[9]]
                var thiscommandKeyStr=""
                var kIndex=0
                for keyStr in rowList {
                    let thisKeyStr=String(describing: rowList[kIndex])
                    kIndex+=1
                    if !thisKeyStr.isEmpty {
                        if (thiscommandKeyStr.isEmpty) {
                            thiscommandKeyStr=keyStr
                        } else {
                            thiscommandKeyStr=thiscommandKeyStr+"+"+keyStr
                        }
                    }
                }

                if index>1 {
                    thisPk=thisPk+1
                    addShortcut(
                        pk: thisPk,
                        category: row[1],
                        category_hangul: row[2],
                        ctrl: row[3],
                        alt: row[4],
                        shift: row[5],
                        key1: row[6],
                        key2: row[7],
                        key3: row[8],
                        key4: row[9],
                        commandString: row[10],
                        searchString: row[11],
                        score: thisScore,
                        favorite: thisFavorite,
                        commandKeyStr: thiscommandKeyStr
                    )
                }
            }
            //즐겨찾기 정보 복원
            if savedFavoriteData.count > 0 {
                print("restore favorite data...")
                let realm = try! Realm()
                let shortCutDB=realm.objects(Shortcut.self)
                var thiscategory: String = ""
                var thisctrl: String = ""
                var thisalt: String = ""
                var thisshift: String = ""
                var thiskey1: String = ""
                var thiskey2: String = ""
                var thiskey3: String = ""
                var thiskey4: String = ""
                for favorite in savedFavoriteData {
                    thiscategory=favorite["category"]!
                    thisctrl=favorite["ctrl"]!
                    thisalt=favorite["alt"]!
                    thisshift=favorite["shift"]!
                    thiskey1=favorite["key1"]!
                    thiskey2=favorite["key2"]!
                    thiskey3=favorite["key3"]!
                    thiskey4=favorite["key4"]!
                    let thisQuery: String = "category='"+thiscategory+"' and ctrl='"+thisctrl+"' and alt='"+thisalt+"' and shift='"+thisshift+"' and key1='"+thiskey1+"' and key2='"+thiskey2+"' and key3='"+thiskey3+"' and key4='"+thiskey4+"'"
                    try! realm.write {
                        shortCutDB.filter(thisQuery).setValue(1, forKey: "favorite")
                    }
                }
            }
            print("DB update success")
            //print(NSHomeDirectory())
            
            //버전 관리를 위한 파일을 생성한다.
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let documentsURLString = documentsURL.absoluteString.replacingOccurrences(of: "file://", with: "")
            //기존 버전관리 파일 삭제
            do {
                let filePaths = try fileManager.contentsOfDirectory(atPath: documentsURLString)
                for filePath in filePaths {
                    let data=filePath.components(separatedBy: ".")
                    if data[1]=="txt" {
                        try fileManager.removeItem(atPath: documentsURLString + filePath)
                    }
                }
            } catch let error as NSError {
                print("Could not clear temp folder: \(error.debugDescription)")
            }

            let fileURL = documentsURL.appendingPathComponent(csvFileName+".txt")
            let myTextString = NSString(string: "DB파일 버전 : "+csvFileName)
            try? myTextString.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8.rawValue)
            let reCheckDBVersionSync=checkFileExist(checkFileName: csvFileName, checkFileType: "txt")
            if !reCheckDBVersionSync {
                print("버전 관리파일 생성 실패")
                print("DB initializing is failed")
            } else {
                print("DB initializing is completed")
            }
        }
        //설정값 저장 여부 확인 후 저장되어 있지 않다면 초기화
        initFileterSetting()
    }
    
    func readDataFromCSV(fileName:String, fileType:String)-> String!{
        //let bundlePath = Bundle.main.bundlePath
        let fileNameInBundle = Bundle.main.path(forResource:fileName, ofType: fileType)!
        //print(fileNameInBundle)
        do {
            let contents = try String(contentsOfFile: fileNameInBundle, encoding: .utf8)
            return contents
        } catch {
            print("File Read Error for file \(fileName)")
            return nil
        }
    }
    
    func getArrFromCsvString(data: String) -> [[String]] {
        var result: [[String]] = []
        let rows = data.components(separatedBy: "\n")
        for row in rows {
            let columns = row.components(separatedBy: ",")
            result.append(columns)
        }
        //print(result)
        return result
    }
    
    func cleanRows(file:String)->String{
        var cleanFile = file
        cleanFile = cleanFile.replacingOccurrences(of: "\r", with: "\n")
        cleanFile = cleanFile.replacingOccurrences(of: "\n\n", with: "\n")
        return cleanFile
    }

    func checkFileExist(checkFileName : String, checkFileType: String) -> Bool {
        var result=false
        let fileMgr: FileManager = FileManager.default
        let fileNameOrg=FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.absoluteString+checkFileName+"."+checkFileType
        let fileName=fileNameOrg.replacingOccurrences(of: "file://", with: "")
        print(fileName)
        let fileExist = fileMgr.fileExists(atPath: fileName)
        if (fileExist) {
            result=true
        }
        return result
    }
    func removeDB() {
        print("remove DB...")
        //기존에 저장된 즐겨찾기 정보 저장
        if checkFileExist(checkFileName: "default", checkFileType: "realm") == true {
            let realm = try! Realm()
            let dataList = realm.objects(Shortcut.self).filter("favorite=1")
            if dataList.count > 0 {
                var thisDic = [String : String]()
                for data in dataList {
                    thisDic = [
                        "category" : data["category"] as! String,
                        "ctrl" : data["ctrl"] as! String,
                        "alt" : data["alt"] as! String,
                        "shift" : data["shift"] as! String,
                        "key1" : data["key1"] as! String,
                        "key2" : data["key2"] as! String,
                        "key3" : data["key3"] as! String,
                        "key4" : data["key4"] as! String
                    ]
                    savedFavoriteData.append(thisDic)
                }
            }
            do {
                try realm.write {
                    realm.delete(realm.objects(Shortcut.self))
                }
                print("DB remove success")
            } catch {
                print("DB remove failed")
            }
        }
    }
    func addShortcut(pk:Int, category:String, category_hangul:String, ctrl:String, alt:String, shift:String, key1:String, key2:String, key3:String, key4:String, commandString:String, searchString:String, score: Int, favorite:Int, commandKeyStr:String) {
        let shortcut = Shortcut()
        shortcut.pk=pk
        shortcut.category=category
        shortcut.category_hangul=category_hangul
        shortcut.ctrl=ctrl
        shortcut.alt=alt
        shortcut.shift=shift
        shortcut.key1=key1
        shortcut.key2=key2
        shortcut.key3=key3
        shortcut.key4=key4
        shortcut.commandString=commandString
        shortcut.searchString=searchString
        shortcut.favorite=favorite
        shortcut.commandKeyStr=commandKeyStr
        let realm = try! Realm()
        do {
            try realm.write {
                realm.add(shortcut)
            }
        } catch {
            print("error")
        }
    }
    func initFileterSetting() {
        let realm = try! Realm()
        let dataList = realm.objects(Setting.self)
        if dataList.count>0 {
            print("저장된 필터세팅 정보 존재")
        } else {
            print("저장된 필터세팅 정보 없음. 필터세팅 정보 초기화")
            let setting = Setting()
            setting.powerpoint=true
            setting.excel=true
            setting.word=true
            setting.hangul=true
            setting.chrome=true
            setting.windows=true
            try! realm.write {
                realm.add(setting)
            }
        }
    }
}

class TabBarController: UITabBarController, UITabBarControllerDelegate {
    override func loadView() {
        super.loadView()
//        print("view load")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("tabBar view loaded")
        //DB셋업
        let setupDB=setupDatabase()
        setupDB.initDB()
        self.tabBarController?.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //print("view did appeard")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
//    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
//        //print("tab selected")
//    }
}

class searchMenuController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var searchTextField: UISearchBar!
    @IBOutlet weak var searchResultTable: UITableView!
    @IBOutlet weak var bannerView: GADBannerView!
    
    override func loadView() {
        super.loadView()
        //print("search menu view load")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("search menu view loaded")
        searchResultTable.delegate = self
        searchResultTable.dataSource = self
        searchTextField.delegate = self
        
        //구글 광고 삽입
        bannerView.adUnitID = adUnitId1
        bannerView.rootViewController = self
        bannerView.load(GADRequest())
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //print("search view did appeared")
        if searchTableReloadCheck {
            print("setting changed. it will reload")
            print("reload...")
            searchResultTable.reloadData()
            searchTableReloadCheck=false
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        //구글 광고 새롭게 로드
        bannerView.load(GADRequest())
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func getQuery() -> String {
        var query=""
        let realm = try! Realm()
        let settingData = realm.objects(Setting.self)
        for field in settingFieldList {
            if settingData[0][field] as! Bool {
                if (query=="") {
                    query="(category='"+field+"'"
                } else {
                    query=query+" or category='"+field+"'"
                }
            }
        }
        if query != "" {
            query=query+")"
        }
        let searchText=searchTextField.text!
        if searchText != "" && query != "" {
            query=query+" and (commandString CONTAINS[c] '"+searchText+"' or searchString CONTAINS[c] '"+searchText+"' or commandKeyStr CONTAINS[c] '"+searchText+"' or category CONTAINS[c] '"+searchText+"' or category_hangul CONTAINS[c] '"+searchText+"')"
        }
        //print(query)
        return query
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var result: Int=0
        let query=self.getQuery()
        if query == "" {
            result=1
        } else {
            let realm = try! Realm()
            let dataList = realm.objects(Shortcut.self).filter(query)
            result=dataList.count
        }
        return result
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let query=self.getQuery()
        let cell =
        tableView.dequeueReusableCell(
            withIdentifier: "searchResultCell",
            for: indexPath
        ) as! customCell
        
        if query == "" {
            cell.cellCategoryName.text = "none"
            cell.cellCommandKey.text = "필터가 모두 Off 되었습니다."
            cell.cellContent.text = "필터 설정 메뉴에서 설정을 변경해 주세요."
            cell.cellCategoryIcon.image = UIImage(named:"none")
            cell.cellFavoriteBtn.isHidden = true
        } else {
            let realm = try! Realm()
            let dataList = realm.objects(Shortcut.self).filter(query)
            
            let currentRowOfList = dataList[indexPath.row]
            let cellCategoryIconName=switchCategoryToStandardNameEng(categoryName : currentRowOfList["category"] as! String)
            let cellCategoryNameKor=switchCategoryToStandardNameKor(categoryName : currentRowOfList["category"] as! String)
            
            cell.cellCategoryName.text = cellCategoryNameKor
            cell.cellCommandKey.text = currentRowOfList["commandKeyStr"] as? String
            cell.cellContent.text = currentRowOfList["commandString"] as? String
            cell.cellCategoryIcon.image = UIImage(named:cellCategoryIconName)
            if currentRowOfList["favorite"] as! Int8 == 1 {
                cell.cellFavoriteBtn.setImage(UIImage(systemName:"star.fill"), for: .normal)
                cell.cellFavoriteBtn.tintColor = UIColor.systemBlue
            } else {
                cell.cellFavoriteBtn.setImage(UIImage(systemName:"star"), for: .normal)
                cell.cellFavoriteBtn.tintColor = UIColor.lightGray
            }
            cell.cellFavoriteBtn.tag = currentRowOfList["pk"] as! Int // for detect which row switch Changed
            cell.cellFavoriteBtn.isHidden = false
            cell.cellFavoriteBtn.addTarget(self, action: #selector(self.favorieRegBtnClicked(_:)), for: .touchUpInside)
        }
        return cell
    }
    
    //cell 클릭 시 이벤트
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        let cell = tableView.cellForRow(at: indexPath) as! customCell
        let thisTitle=cell.cellCommandKey.text ?? "단축키"
        var thisContent=cell.cellContent.text ?? "설명"
        thisContent="\n"+thisContent+"\n"
        
        let alert = UIAlertController(title: thisTitle, message: thisContent, preferredStyle: UIAlertController.Style.alert)
        let okAction = UIAlertAction(title: "닫기", style: .default, handler : nil )
        
        //alert창 커스터마이징~
        alert.setTitleFontStyle(font: UIFont.boldSystemFont(ofSize: CGFloat(22.0)), color: UIColor.black)
        alert.setMessageFontStyle(font: UIFont(name: "AppleSDGothicNeo-Regular", size:18), color: UIColor.black)
        
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    @objc func favorieRegBtnClicked(_ sender : UIButton!) {
        //print(sender.tag)
        let thisPk=String(sender.tag)
        let realm = try! Realm()
        let thisData = realm.objects(Shortcut.self).filter("pk="+thisPk)
        let thisFavoriteStatus = thisData[0]["favorite"] as! Int
        var newFavoriteStatus: Int8 = 0
        if thisFavoriteStatus == 0 {
            newFavoriteStatus = 1
        }
        let shortCutDB=realm.objects(Shortcut.self)
        try! realm.write {
            shortCutDB.filter("pk="+thisPk).setValue(newFavoriteStatus, forKey: "favorite")
        }
        print("favorite button clicked...")
        searchResultTable.reloadData()
    }
    
    func switchCategoryToStandardNameEng(categoryName : String) -> String {
        var standardNameEng="none"
        switch categoryName {
            case "powerpoint":
                standardNameEng="powerpoint"
            case "excel":
                standardNameEng="excel"
            case "word":
                standardNameEng="word"
            case "hangul":
                standardNameEng="hangul"
            case "chrome":
                standardNameEng="chrome"
            case "windows":
                standardNameEng="windows"
            default:
                standardNameEng="none"
        }
        return standardNameEng
    }
    
    func switchCategoryToStandardNameKor(categoryName : String) -> String {
        var standardNameKor="none"
        switch categoryName {
            case "powerpoint":
                standardNameKor="파워포인트"
            case "excel":
                standardNameKor="엑셀"
            case "word":
                standardNameKor="워드"
            case "hangul":
                standardNameKor="아래아한글"
            case "chrome":
                standardNameKor="크롬"
            case "windows":
                standardNameKor="윈도우"
            default:
                standardNameKor="none"
        }
        return standardNameKor
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        //print("searching...")
        searchResultTable.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.searchTextField.text = ""
        self.searchTextField.resignFirstResponder()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.searchTextField.resignFirstResponder()
    }
}

class quizMenuController: UIViewController, GADInterstitialDelegate {
    @IBOutlet weak var quizStartView: UIView!
    @IBOutlet weak var quizContentView: UIView!

    @IBOutlet weak var quizStartViewImage: UIImageView!
    @IBOutlet weak var quizStartViewExplain: UITextView!
    @IBOutlet weak var quizStartBtn: UIButton!
    @IBOutlet weak var quizContentViewQuitBtn: UIButton!
    @IBOutlet weak var quizContentViewNowQuestionNo: UITextView!
    @IBOutlet weak var quizContentViewQuestionExplain: UITextView!
    @IBOutlet weak var quizContentViewCategoryImage: UIImageView!
    @IBOutlet weak var quizContentCategoryName: UILabel!
    @IBOutlet weak var quizContentViewQuestion: UITextView!
    @IBOutlet weak var quizContentViewOption1: UIButton!
    @IBOutlet weak var quizContentViewOption2: UIButton!
    @IBOutlet weak var quizContentViewOption3: UIButton!
    @IBOutlet weak var quizContentViewOption4: UIButton!
    @IBOutlet weak var quizContentViewOption5: UIButton!
    
    //구글 전면광고 객체 생성
    var interstitial: GADInterstitial!
    var questionData : Array<[String : Any?]> = []
    let questionMaxCnt : Int = 10
    var questionCntNo : Int = 1
    var score : Int = 0
    var wantMoreQuizCheck = false
    
    override func loadView() {
        super.loadView()
        quizContentView.isHidden = true
        //print("quiz menu view load")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("quiz menu view loaded")
        interstitial = createAndLoadInterstitial()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //print("search view did appeared")
    }
    
    func createAndLoadInterstitial() -> GADInterstitial {
      let interstitial = GADInterstitial(adUnitID: adUnitId2)
      interstitial.delegate = self
      interstitial.load(GADRequest())
      return interstitial
    }

    //광고 닫음 버튼을 클릭함
    func interstitialDidDismissScreen(_ ad: GADInterstitial) {
        interstitial = createAndLoadInterstitial()
        loadQuiz()
    }
    
    //델리게이트에게 광고 요청이 성공했음을 알림
    func interstitialDidReceiveAd(_ ad: GADInterstitial) {
        print("interstitialDidReceiveAd")
    }

    //델리게이트에게 광고 요청이 실패했음을 알림
    func interstitial(_ ad: GADInterstitial, didFailToReceiveAdWithError error: GADRequestError) {
        print("interstitial:didFailToReceiveAdWithError: \(error.localizedDescription)")
    }

    //델리게이트에게 광고가 나타날 것임을 알림
    func interstitialWillPresentScreen(_ ad: GADInterstitial) {
        print("interstitialWillPresentScreen")
    }

    //광고 닫음 버튼을 클릭할 것임을 알림
    func interstitialWillDismissScreen(_ ad: GADInterstitial) {
        print("interstitialWillDismissScreen")
    }

    //광고를 터치하여 다른 앱이나 화면으로 넘어갔음을 알림
    func interstitialWillLeaveApplication(_ ad: GADInterstitial) {
        print("interstitialWillLeaveApplication")
        loadQuiz()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
        
    @IBAction func quizStartBtnClicked(_ sender: UIButton) {
        //퀴즈에 처음 참여할 때는 광고없이 바로 체험하도록 함
        if wantMoreQuizCheck { //두 번째 이상 퀴즈에 응하는 것인가?
            if interstitial.isReady {
                //광고가 로드되었다면 광고 시청 후 넘어가도록 함
                interstitial.present(fromRootViewController: self)
            } else {
                //광고가 로드되지 않았다면 바로 퀴즈 실행화면으로 넘어감
                print("Ad wasn't ready")
                loadQuiz()
            }
        } else {
            loadQuiz()
        }
    }
    
    @IBAction func quizQuitBtnClicked(_ sender: Any) {
        resetQuizStartView()
    }
    
    @IBAction func quizOptionClicked(_ sender: Any) {
        questionCntNo+=1
        let button = sender as! UIButton
        var alert = UIAlertController()
        var okAction = UIAlertAction()
        
        if button.tag == 1 {
            alert = UIAlertController(title: "결과", message: "\n정답입니다!", preferredStyle: UIAlertController.Style.alert)
            score += 1
        } else {
            let optionButtons: [UIButton] = [quizContentViewOption1, quizContentViewOption2, quizContentViewOption3, quizContentViewOption4, quizContentViewOption5]
            var correctStr = ""
            for button in optionButtons {
                if button.tag == 1 {
                    correctStr = button.currentTitle!
                    break
                }
            }
            alert = UIAlertController(title: "오답입니다!", message: "\n정답은\n'"+correctStr+"'\n입니다.", preferredStyle: UIAlertController.Style.alert)
        }

        if questionCntNo == questionMaxCnt+1 {
           okAction = UIAlertAction(title: "최종결과 확인", style: .default, handler : {action in self.printQuizResult()})
        } else {
            okAction = UIAlertAction(title: "다음 문제풀기", style: .default, handler : {action in self.printQuiz(thisQuestionCntNo: self.questionCntNo)})
        }
        
        //alert창 커스터마이징~
        alert.setTitleFontStyle(font: UIFont.boldSystemFont(ofSize: CGFloat(22.0)), color: UIColor.black)
        alert.setMessageFontStyle(font: UIFont(name: "AppleSDGothicNeo-Regular", size:18), color: UIColor.black)

        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    func loadQuiz() {
        let query=getQuery()
        if query == "" {
            loadQuizAlert()
        } else {
            questionData = []
            let realm = try! Realm()
            let dataList = realm.objects(Shortcut.self).filter(query)

            //로드한 데이터가 questionMaxCnt 이상 로드되어야만 출력함
            if dataList.count >= questionMaxCnt {
                //랜덤으로 10개 단축키 로드 (필터 적용)
                var numbers:[Int] = []
                while numbers.count < 100 { //중복 시 재시도까지 고려해 넉넉히 100번 돌리자...
                    let number = Int.random(in: 1...dataList.count-1)
                    if !numbers.contains(number) {
                        numbers.append(number)
                    }
                    if (numbers.count==questionMaxCnt) { //문항수 가득 채워지면 중지
                        break
                    }
                }
                //print(numbers)
                //문제를 배열로 저장
                for questionNo in numbers {
                    let thisQuestion = dataList[questionNo]
                    let thisDic = ["qNo" : thisQuestion["pk"], "category" : thisQuestion["category"], "commandKeyStr" : thisQuestion["commandKeyStr"], "commandString" : thisQuestion["commandString"]]
                    questionData.append(thisDic)
                }
                
                //누적 score 초기화
                score = 0
                
                //문항번호 초기화
                questionCntNo = 1
                
                //퀴즈에 참여하였음을 기록
                wantMoreQuizCheck = true
                
                //첫 문제 출제
                printQuiz(thisQuestionCntNo: questionCntNo)
                
                //화면 바꾸기
                quizStartView.isHidden = true
                quizContentView.isHidden = false

            } else {
                loadQuizAlert()
            }
        }
    }
    
    func loadQuizAlert() {
        let alert = UIAlertController(title: "알림", message: "\n문제가 로드되지 않았습니다. 필터 설정 메뉴에서 필터가 On되어 있는지 확인해 주세요!", preferredStyle: UIAlertController.Style.alert)
        let okAction = UIAlertAction(title: "닫기", style: .default, handler : nil)

        //alert창 커스터마이징~
        alert.setTitleFontStyle(font: UIFont.boldSystemFont(ofSize: CGFloat(22.0)), color: UIColor.black)
        alert.setMessageFontStyle(font: UIFont(name: "AppleSDGothicNeo-Regular", size:18), color: UIColor.black)

        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }

    func printQuiz(thisQuestionCntNo: Int) {
        quizContentViewNowQuestionNo.text = String(thisQuestionCntNo)+"/"+String(questionMaxCnt)
        let questionCntNoForArr = thisQuestionCntNo-1
        let thisQuestionData = questionData[questionCntNoForArr]
        let categoryNameEng = searchMenuController().switchCategoryToStandardNameEng(categoryName : thisQuestionData["category"] as! String)
        let categoryNameKor = searchMenuController().switchCategoryToStandardNameKor(categoryName : thisQuestionData["category"] as! String)
        let thisCommandKeyStr = thisQuestionData["commandKeyStr"] as! String
        let thisCommandString = thisQuestionData["commandString"] as! String
        //문항 유형을 어떤 것으로 할 것인가.. 랜덤 선택
        let cate = Int.random(in: 1...2)
        //문제 출력
        var correctOptionStr: String = ""
        var correctOptionCate: String = ""
        quizContentViewCategoryImage.image = UIImage(named: categoryNameEng)
        quizContentCategoryName.text = categoryNameKor
        if cate == 1 { //단축키 명령어가 문제로 나오는 유형
            correctOptionCate = "commandString"
            quizContentViewQuestionExplain.text = "아래 단축키로 할 수 있는 작업은 무엇일까요?"
            quizContentViewQuestion.text = thisCommandKeyStr
        } else if cate == 2 { //단축키 설명이 문제로 나오는 유형
            correctOptionCate = "commandKeyStr"
            quizContentViewQuestionExplain.text = "아래 작업을 할 수 있는 단축키는 무엇일까요?"
            quizContentViewQuestion.text = thisCommandString
        }
        correctOptionStr = thisQuestionData[correctOptionCate] as! String
        adjustContentSize(tv: quizContentViewQuestion)

        let optionButtons: [UIButton] = [quizContentViewOption1, quizContentViewOption2, quizContentViewOption3, quizContentViewOption4, quizContentViewOption5]
        
        //오답 추출
        let realm = try! Realm()
        let thisCategoryForOption = thisQuestionData["category"] as! String
        let thisCommandKeyStrForOption = thisQuestionData["commandKeyStr"] as! String
        let thisPkForOption = thisQuestionData["qNo"] as! Int
        let query="category='"+thisCategoryForOption+"' and commandKeyStr!='"+thisCommandKeyStrForOption+"' and pk!="+String(thisPkForOption)
        let dataList = realm.objects(Shortcut.self).filter(query)
        //랜덤으로 오답 4개 로드
        var anotherOptionList:[String] = []
        while anotherOptionList.count < 10 { //중복 시 재시도까지 고려해 넉넉히 10번 돌리자...
            let number = Int.random(in: 1...dataList.count-1)
            if !anotherOptionList.contains(dataList[number][correctOptionCate] as! String) {
                anotherOptionList.append(dataList[number][correctOptionCate] as! String)
            }
            if (anotherOptionList.count==5) { //오답수 가득 채워지면 중지
                break
            }
        }
        //몇번째 보기에 정답을 넣을 것인가.. 랜덤 선택
        let correctOptionNo = Int.random(in: 1...5)
        let correctIdentifierName="quizContentViewOption"+String(correctOptionNo)
        
        var index=0
        for button in optionButtons {
            if button.accessibilityIdentifier == correctIdentifierName {
                button.setTitle(correctOptionStr, for: .normal)
                button.tag = 1
            } else {
                button.setTitle(anotherOptionList[index], for: .normal)
                button.tag = 0
                index+=1
            }
        }
    }
    
    func printQuizResult() {
        let finalScore = String(score*10)
        let alert = UIAlertController(title: "최종 결과", message: "\n총 "+String(questionMaxCnt)+"문제 중 "+String(score)+"문제를 맞춰 최종 점수는 "+finalScore+"점입니다.", preferredStyle: UIAlertController.Style.alert)
        let okAction = UIAlertAction(title: "확인", style: .default, handler : {action in self.resetQuizStartView()})
        
        //alert창 커스터마이징~
        alert.setTitleFontStyle(font: UIFont.boldSystemFont(ofSize: CGFloat(22.0)), color: UIColor.black)
        alert.setMessageFontStyle(font: UIFont(name: "AppleSDGothicNeo-Regular", size:18), color: UIColor.black)

        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    func resetQuizStartView() {
        quizStartView.isHidden = false
        quizContentView.isHidden = true
    }
    
    func getQuery() -> String {
        var query=""
        let realm = try! Realm()
        let settingData = realm.objects(Setting.self)
        for field in settingFieldList {
            if settingData[0][field] as! Bool {
                if (query=="") {
                    query="(category='"+field+"'"
                } else {
                    query=query+" or category='"+field+"'"
                }
            }
        }
        if query != "" {
            query=query+")"
        }
        //print(query)
        return query
    }
    
    func adjustContentSize(tv: UITextView){
        let deadSpace = tv.bounds.size.height - tv.contentSize.height
        let inset = max(0, deadSpace/2.0)
        tv.contentInset = UIEdgeInsets(top: inset, left: tv.contentInset.left, bottom: inset, right: tv.contentInset.right)
    }
}

class favoriteMenuController: UIViewController, UITableViewDelegate, UITableViewDataSource {
        
    @IBOutlet weak var favoriteResultTable: UITableView!
    @IBOutlet weak var bannerView: GADBannerView!
    
    override func loadView() {
        super.loadView()
        //print("favorite menu view load")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("favorite menu view loaded")
        favoriteResultTable.delegate = self
        favoriteResultTable.dataSource = self
        
        //구글 광고 삽입
        bannerView.adUnitID = adUnitId3
        bannerView.rootViewController = self
        bannerView.load(GADRequest())
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        favoriteResultTable.reloadData()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        //구글 광고 새롭게 로드
        bannerView.load(GADRequest())
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var result: Int=0
        let realm = try! Realm()
        let dataList = realm.objects(Shortcut.self).filter("favorite=1")
        result=dataList.count
        
        //즐겨찾기 등록된 게 없다면 알림셀을 출력하기 위해 1행은 추가해 준다.
        if result==0 {
            result=1
        }
        return result
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =
        tableView.dequeueReusableCell(
            withIdentifier: "favoriteResultCell",
            for: indexPath
        ) as! customCell
        
        let realm = try! Realm()
        let dataList = realm.objects(Shortcut.self).filter("favorite=1")
        
        if dataList.count==0 {
            cell.cellFavoriteCategoryName.text = "none"
            cell.cellFavoriteCommandKey.text = "등록한 나의 단축키가 없어요!"
            cell.cellFavoriteContent.text = "단축키 사전에서 별표를 눌러보세요^^"
            cell.cellFavoriteCategoryIcon.image = UIImage(named:"none")
        } else {
            let currentRowOfList = dataList[indexPath.row]
            let cellCategoryIconName=searchMenuController().switchCategoryToStandardNameEng(categoryName : currentRowOfList["category"] as! String)
            let cellCategoryNameKor=searchMenuController().switchCategoryToStandardNameKor(categoryName : currentRowOfList["category"] as! String)
            
            cell.cellFavoriteCategoryName.text = cellCategoryNameKor
            cell.cellFavoriteCommandKey.text = currentRowOfList["commandKeyStr"] as? String
            cell.cellFavoriteContent.text = currentRowOfList["commandString"] as? String
            cell.cellFavoriteCategoryIcon.image = UIImage(named:cellCategoryIconName)
        }
        return cell
    }
    
    //cell 클릭 시 이벤트
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        let cell = tableView.cellForRow(at: indexPath) as! customCell
        let thisTitle=cell.cellFavoriteCommandKey.text ?? "단축키"
        var thisContent=cell.cellFavoriteContent.text ?? "설명"
        thisContent="\n"+thisContent+"\n"
        
        let alert = UIAlertController(title: thisTitle, message: thisContent, preferredStyle: UIAlertController.Style.alert)
        let okAction = UIAlertAction(title: "닫기", style: .default, handler : nil )
        
        //alert창 커스터마이징~
        alert.setTitleFontStyle(font: UIFont.boldSystemFont(ofSize: CGFloat(22.0)), color: UIColor.black)
        alert.setMessageFontStyle(font: UIFont(name: "AppleSDGothicNeo-Regular", size:18), color: UIColor.black)
        
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
}

class settingMenuController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var settingTable: UITableView!
    @IBOutlet weak var bannerView: GADBannerView!
    
    override func loadView() {
        super.loadView()
//        print("setting menu view load")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("setting menu view loaded")
        settingTable.delegate = self
        settingTable.dataSource = self
        
        //구글 광고 삽입
        bannerView.adUnitID = adUnitId4
        bannerView.rootViewController = self
        bannerView.load(GADRequest())
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        //구글 광고 새롭게 로드
        bannerView.load(GADRequest())
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingFieldList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let realm = try! Realm()
        let dataList = realm.objects(Setting.self)
        
        let cell =
        tableView.dequeueReusableCell(
            withIdentifier: "settingCell",
            for: indexPath
        ) as! customCell
        
        let thisField=settingFieldList[indexPath.row]
        let thisSettingBool = dataList[0][thisField] as? Bool
        
        //스위치 설정
        if thisSettingBool! {
            cell.cellSettingSwitch.setOn(true, animated: true)
        } else {
            cell.cellSettingSwitch.setOn(false, animated: true)
        }
        cell.cellSettingSwitch.tag = indexPath.row // for detect which row switch Changed
        cell.cellSettingSwitch.addTarget(self, action: #selector(self.switchChanged(_:)), for: .valueChanged)
        
        cell.cellSettingTitle.text = thisField
        cell.cellSettingIcon.image = UIImage(named:thisField)
        
        return cell
    }
    
    @objc func switchChanged(_ sender : UISwitch!) {
        var thisValue=false
        if sender.isOn {
            thisValue=true
        }
        let thisFieldName=settingFieldList[sender.tag]
        let realm = try! Realm()
        let settingDB=realm.objects(Setting.self)
        try! realm.write {
            settingDB.first?.setValue(thisValue, forKey: thisFieldName)
        }
        searchTableReloadCheck=true
        print("\(settingFieldList[sender.tag]) switch is \(sender.isOn ? "ON" : "OFF") and updated")
    }
}

class customCell: UITableViewCell {
    @IBOutlet weak var cellCategoryName: UILabel!
    @IBOutlet weak var cellContent: UILabel!
    @IBOutlet weak var cellCommandKey: UILabel!
    @IBOutlet weak var cellCategoryIcon: UIImageView!
    @IBOutlet weak var cellFavoriteBtn: UIButton!
    
    @IBOutlet weak var cellFavoriteCategoryName: UILabel!
    @IBOutlet weak var cellFavoriteContent: UILabel!
    @IBOutlet weak var cellFavoriteCommandKey: UILabel!
    @IBOutlet weak var cellFavoriteCategoryIcon: UIImageView!
    
    @IBOutlet weak var cellSettingTitle: UILabel!
    @IBOutlet weak var cellSettingSwitch: UISwitch!
    @IBOutlet weak var cellSettingIcon: UIImageView!
    
    
}

//세부내용 창 서식 바꾸는 extension
extension UIAlertController {
    
    //Set background color of UIAlertController
    func setBackgroundColor(color: UIColor) {
        if let bgView = self.view.subviews.first, let groupView = bgView.subviews.first, let contentView = groupView.subviews.first {
            contentView.backgroundColor = color
        }
    }
    

    //Set title font and title color
    func setTitleFontStyle(font: UIFont?, color: UIColor?) {
        guard let title = self.title else { return }
        let attributeString = NSMutableAttributedString(string: title)//1
        if let titleFont = font {
            attributeString.addAttributes([NSAttributedString.Key.font : titleFont],//2
                                          range: NSMakeRange(0, title.count))
        }
        
        if let titleColor = color {
            attributeString.addAttributes([NSAttributedString.Key.foregroundColor : titleColor],//3
                                          range: NSMakeRange(0, title.count))
        }
        self.setValue(attributeString, forKey: "attributedTitle")//4
    }
    
    //Set message font and message color
    //************* message.count 와 message.utf.count 차이가 있음...
    func setMessageFontStyle(font: UIFont?, color: UIColor?) {
        guard let message = self.message else { return }
        let attributeString = NSMutableAttributedString(string: message)
        if let messageFont = font {
            attributeString.addAttributes([NSAttributedString.Key.font : messageFont],
                                          range: NSMakeRange(0, message.count))
        }

        if let messageColorColor = color {
            attributeString.addAttributes([NSAttributedString.Key.foregroundColor : messageColorColor],
                                          range: NSMakeRange(0, message.count))
        }
        self.setValue(attributeString, forKey: "attributedMessage")
    }
    
    //Set tint color of UIAlertController
    func setTint(color: UIColor) {
        self.view.tintColor = color
    }
}
