*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.HTTP
Library             RPA.Tables
Library             RPA.Browser.Selenium
Library             Collections
Library             RPA.Desktop
Library             RPA.PDF
Library             RPA.Archive
Library             RPA.Dialogs
Library             RPA.Robocorp.Vault
Library             OperatingSystem


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    #ask user to input csv url
    ${orders_csv_url}=    Input csv url

    #validate csv url
    IF    "${orders_csv_url}" != "https://robotsparebinindustries.com/orders.csv"
        Fail    Invalid orders csv url
    END

    # download orders csv
    Download    ${orders_csv_url}    overwrite=True

    # read orders from csv file
    ${orders}=    Read table from CSV    orders.csv

    #get url from vault
    ${secret_data}=    Get Secret    secret_data
    ${order_robot_url}=    Get From Dictionary    ${secret_data}    order_robot_url

    # open browser
    Open Chrome Browser    ${order_robot_url}

    FOR    ${order}    IN    @{orders}
        create order    ${order}
    END

    #create zip with all receipt
    Archive Folder With Zip    receipts_with_images    ${OUTPUT_DIR}${/}receipts_with_images.zip

    # Empty folders and delete files
    Remove Directory    receipts_with_images    recursive=${True}
    Remove Directory    receipts    recursive=${True}
    Remove Directory    robot_images    recursive=${True}
    Remove File    orders.csv


*** Keywords ***
create order
    [Arguments]    ${order}

    #create required folders
    Create Directory    receipts_with_images
    Create Directory    receipts
    Create Directory    robot_images

    # wait for popup to appear
    Wait Until Page Contains Element    class:modal-body

    # click ok to dismiss popup
    Click Button    OK

    #Order number,Head,Body,Legs,Address
    #1,1,2,3,Address 123
    Log To Console    ${order}
    ${order_number}=    Set Variable    ${order}[Order number]
    ${head_number}=    Set Variable    ${order}[Head]
    ${body_number}=    Set Variable    ${order}[Body]
    ${legs_number}=    Set Variable    ${order}[Legs]
    ${address}=    Set Variable    ${order}[Address]

    #select head
    Select From List By Value    head    ${head_number}

    #select body
    Select Radio Button    body    ${body_number}

    # set number of legs
    Input Text    xpath://*[@placeholder="Enter the part number for the legs"]    ${legs_number}

    # set address
    Input Text    id:address    ${address}

    # preview robot
    Click Button    Preview

    # wait for robot image to appear
    Wait Until Page Contains Element    id:robot-preview-image

    # order robot
    Click Button    Order

    # click again until it succeeds
    ${error_alert_visible}=    Does Page Contain Element    class:alert-danger
    WHILE    ${error_alert_visible}
        Click Button    Order
        ${error_alert_visible}=    Does Page Contain Element    class:alert-danger
    END

    # wait for order confirmation page
    Wait Until Page Contains Element    id:receipt
    Wait Until Page Contains Element    id:robot-preview-image

    # screenshot the robot
    Screenshot    id:robot-preview-image    robot_images${/}robot_preview_${order_number}.png

    # save receipt as pdf
    ${receipt_html}=    Get Element Attribute    id:receipt    outerHTML
    Html To Pdf    ${receipt_html}    receipts${/}receipt_${order_number}.pdf

    # create pdf receipt with image
    ${files}=    Create List
    ...    receipts${/}receipt_${order_number}.pdf
    ...    robot_images${/}robot_preview_${order_number}.png

    Add Files To PDF    ${files}    receipts_with_images${/}receipt_with_image_${order_number}.pdf

    # order another robot
    Click Button    Order another robot

Input csv url
    Add heading    Orders csv
    Add text input    order_csv_url    label=URL    placeholder=https://robotsparebinindustries.com/orders.csv
    ${result}=    Run dialog
    RETURN    ${result.order_csv_url}
