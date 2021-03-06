kd = require 'kd'
JView = require 'app/jview'
WizardSteps = require './wizardsteps'
WizardProgressPane = require './wizardprogresspane'
IDETailerPane = require 'ide/workspace/panes/idetailerpane'

module.exports = class BuildStackLogsPageView extends JView

  constructor: (options = {}, data) ->

    super options, data

    @progressPane = new WizardProgressPane
      currentStep : WizardSteps.BuildStack

    @startCodingButton = new kd.ButtonView
      title    : 'Start Coding'
      cssClass : 'GenericButton'
      callback : @lazyBound 'emit', 'ClosingRequested'

    @logsContainer = new kd.CustomHTMLView { cssClass : 'logs-pane' }
    @render()


  render: ->

    { tailOffset } = @getOptions()
    file = @getData()

    @logsContainer.destroySubViews()
    return  unless file

    logsPane = new IDETailerPane {
      file
      tailOffset
      delegate : this
    }
    @logsContainer.addSubView logsPane


  pistachio: ->

    '''
      <div class="build-stack-flow build-stack-logs-page">
        <header>
          <h1>Build Your Stack</h1>
        </header>
        {{> @progressPane}}
        <section class="main">
          {{> @logsContainer}}
        </section>
        <footer>
          {{> @startCodingButton}}
        </footer>
      </div>
    '''
