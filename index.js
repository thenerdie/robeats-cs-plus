const { WebSocketServer } = require('ws')

const { FlexLayout, QWidget, QLabel, QMainWindow, QFontDatabase, AlignmentFlag } = require('@nodegui/nodegui')

QFontDatabase.addApplicationFont(__dirname + '/fonts/Poppins-Bold.ttf')
const id = QFontDatabase.addApplicationFont(__dirname + '/fonts/Poppins-Thin.ttf')

console.log(QFontDatabase.applicationFontFamilies(id))

const win = new QMainWindow()
win.setFixedSize(550, 150)

const widget = new QWidget()

win.setCentralWidget(widget)

const layout = new FlexLayout()
widget.setLayout(layout)

const song = new QLabel()
song.setText('No song')
song.setInlineStyle("font-size: 30px; margin-bottom: 10px; margin-top: 5px; background-color: #255f63; border-radius: 10px;")

layout.addWidget(song)

const spread = new QLabel()
spread.setText('0 / 0 / 0 / 0 / 0 / 0')
spread.setInlineStyle("font-size: 30px; font-family: 'Poppins'; margin-left: 7px;")
spread.setAlignment(AlignmentFlag.AlignRight)

layout.addWidget(spread)

win.setStyleSheet("font-family: 'Poppins'; background-color: #04F404; color: #e8e8e8;")

win.show()

const server = new WebSocketServer({ port: 8080 })

server.on('connection', ws => {
    ws.on("message", message => {
        const data = JSON.parse(message)
        switch (data.type) {
            case "updateScore":
                spread.setText(`${data.marvelous} / ${data.perfect} / ${data.great} / ${data.good} / ${data.bad} / ${data.miss}`)
                break
            case "updateSong":
                song.setText(data.artist + ' - ' + data.title)
                break
        }
    })
})